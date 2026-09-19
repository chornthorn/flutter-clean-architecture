/// `build_runner` entry point: generates the host's module registry with the Rust
/// engine, and hands the result to build_runner so **it** owns the file — a
/// `build_runner clean` or a conflicting output removes it like any other
/// generated asset.
///
/// ```yaml
/// # host app's build.yaml
/// targets:
///   $default:
///     builders:
///       kaisel_generator:kaisel:
///         enabled: true
/// ```
///
/// What each side owns:
///
/// * **build_runner** owns `lib/app/app_modules.g.dart` (the builder's declared
///   output; the engine is asked to return the source rather than write it).
/// * **The engine** writes the micro-package manifests, e.g.
///   `features/profile/lib/profile.kaisel.dart`. They belong to *other* packages,
///   and build_runner forbids a builder writing another package's assets — yet
///   the registry cannot compile until they exist. They are therefore side
///   artifacts: never committed, and removed by `dart run kaisel_generator --clean`.
///
/// The engine is reused across runs, so a Rust change must invalidate this
/// builder: bump [_engineRevision] together with `ENGINE_REVISION` in
/// `src/config.rs` (build_runner rebuilds when a builder's own sources change).
/// If the two disagree the builder fails with that instruction instead of
/// quietly emitting output from an older engine.
library;

import 'dart:io';
import 'dart:isolate';

import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:kaisel_generator/kaisel_generator.dart';

/// Keep in step with `ENGINE_REVISION` in `src/config.rs`.
const _engineRevision = 1;

/// Generated sources are not inputs: reading one would make this builder depend
/// on another generator's output, or on its own.
final _generatedSuffixes = RegExp(r'\.(g|kaisel|config|cqrs)\.dart$');

Builder kaiselBuilder(BuilderOptions options) => KaiselBuilder(options);

class KaiselBuilder implements Builder {
  KaiselBuilder(this.options);

  final BuilderOptions options;

  /// Declared in the host's `build.yaml`, and it must match `kaisel.yaml: output`.
  String get _outputPath =>
      options.config['output'] as String? ?? 'lib/app/app_modules.g.dart';

  /// `$lib$` = this package's `lib/`, so the builder runs for any change under
  /// `lib/` without naming the file that carries `@KaiselInit`.
  @override
  Map<String, List<String>> get buildExtensions => {
        r'$lib$': [_outputPath.replaceFirst(RegExp('^lib/'), '')],
      };

  @override
  Future<void> build(BuildStep buildStep) async {
    final packageRoot = await _packageRoot(buildStep.inputId.package);
    if (packageRoot == null) {
      log.severe('kaisel: cannot resolve the root of ${buildStep.inputId.package}');
      return;
    }

    await _declareDependencies(buildStep);
    final engineReady = await _ensureEngineBuilt();

    final result = await KaiselGenerator.generate(
      root: packageRoot,
      force: true,
      write: false,
    );
    if (!result.success) {
      log.severe('kaisel: ${result.error}');
      return;
    }
    if (result.revision != _engineRevision) {
      log.severe(
        'kaisel: engine revision ${result.revision} does not match the builder '
        '($_engineRevision). Bump ENGINE_REVISION in src/config.rs and '
        '_engineRevision in lib/builder.dart together, then rebuild.',
      );
      return;
    }

    final code = result.code;
    if (code == null) {
      log.severe('kaisel: the engine returned no registry source');
      return;
    }

    final asset = AssetId(buildStep.inputId.package, _outputPath);
    final resolved = result.outputPath;
    if (resolved != null && _normalize(resolved) != _normalize('$packageRoot/$_outputPath')) {
      log.severe(
        'kaisel: kaisel.yaml outputs `$resolved`, but this builder declares '
        '`$_outputPath`. Align them, or declare your own builder with matching '
        '`build_extensions` (see the kaisel_generator README).',
      );
      return;
    }

    await buildStep.writeAsString(asset, code);
    log.info(
      'kaisel: ${result.modulesCount} modules${engineReady ? '' : ' (engine not rebuilt)'} '
      '→ $_outputPath in ${result.elapsedDisplay}',
    );
  }

  /// Reading the host's own sources makes them inputs, so an edit re-runs this
  /// builder. Generated files are skipped: depending on them would mean
  /// depending on another builder's output.
  Future<void> _declareDependencies(BuildStep buildStep) async {
    await for (final asset in buildStep.findAssets(Glob('lib/**/*.dart'))) {
      if (asset.path == _outputPath || _generatedSuffixes.hasMatch(asset.path)) {
        continue;
      }
      try {
        await buildStep.readAsString(asset);
      } on Exception {
        // An unreadable asset is not a reason to fail the build.
      }
    }
  }

  /// The engine ships as a Rust `cdylib`. When it is older than its sources
  /// (someone edited the engine and the Dart side did not change), rebuild it
  /// before generating, so the output is never produced by a stale engine.
  Future<bool> _ensureEngineBuilt() async {
    final packageDir = await _packageRoot('kaisel_generator');
    if (packageDir == null) {
      return true;
    }

    final manifest = File('$packageDir/Cargo.toml');
    final sourceDir = Directory('$packageDir/src');
    if (!manifest.existsSync() || !sourceDir.existsSync()) {
      // A published package has no Rust sources; its dylib ships with it.
      return true;
    }

    final dylib = File('$packageDir/target/release/${_dylibName()}');
    if (dylib.existsSync() && !_isOlderThan(dylib, [manifest, ...sourceDir.listSync()])) {
      return true;
    }

    log.info('kaisel: building the Rust engine (cargo build --release)');
    final build = Process.runSync(
      'cargo',
      ['build', '--release'],
      workingDirectory: packageDir,
    );
    if (build.exitCode != 0) {
      log.warning(
        'kaisel: cargo build failed; using the existing engine.\n${build.stderr}',
      );
    }
    return false;
  }

  bool _isOlderThan(File file, List<FileSystemEntity> sources) {
    final built = file.statSync().modified;
    for (final source in sources) {
      if (source.statSync().modified.isAfter(built)) {
        return true;
      }
    }
    return false;
  }

  static String _dylibName() {
    if (Platform.isMacOS) return 'libkaisel_generator.dylib';
    if (Platform.isWindows) return 'kaisel_generator.dll';
    return 'libkaisel_generator.so';
  }

  /// `package:foo/` resolves to the package's `lib/`, whose parent is its root.
  Future<String?> _packageRoot(String package) async {
    final uri = await Isolate.resolvePackageUri(Uri.parse('package:$package/'));
    if (uri == null || uri.scheme != 'file') {
      return null;
    }
    return _normalize(Directory(uri.toFilePath()).parent.path);
  }

  static String _normalize(String path) =>
      path.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
}
