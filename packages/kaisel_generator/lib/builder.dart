/// The `build_runner` entry point: generates the host's module registry and hands
/// it to build_runner, so **it** owns the file — a `build_runner clean` or a
/// conflicting output removes it like any other generated asset.
///
/// ```yaml
/// # host app's build.yaml
/// targets:
///   $default:
///     builders:
///       kaisel_generator|kaisel:
///         enabled: true
/// ```
///
/// What each side owns:
///
/// * **build_runner** owns `lib/app/app_modules.g.dart` — this builder's declared
///   output — and re-runs the builder for any change under `lib/`.
/// * **The generator** writes the micro-package manifests, e.g.
///   `features/profile/lib/profile.kaisel.dart`. They belong to *other* packages,
///   and build_runner forbids a builder writing another package's assets — yet
///   the registry cannot compile until they exist. They are therefore side
///   artifacts: never committed, and removed by `dart run kaisel_generator --clean`.
///
/// The generator reads `kaisel.yaml` from disk, so a change to that file alone is
/// not an input build_runner tracks (build targets expose `lib/**` and
/// `pubspec.yaml`, not project files at the root): run `dart run kaisel_generator`
/// after editing it, or list it under the target's `sources`.
library;

import 'dart:io';
import 'dart:isolate';

import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:kaisel_generator/kaisel_generator.dart';
import 'package:path/path.dart' as p;

/// Called by `build_runner`: the composition root of a Kaisel build.
///
/// The bootstrap constructs every SPI implementation this build runs — the
/// entry point is the one place that names concrete implementations.
Builder kaiselBuilder(BuilderOptions options) =>
    KaiselBuilder(options, generator: const KaiselBootstrap().createGenerator());

class KaiselBuilder implements Builder {
  KaiselBuilder(this.options, {required this.generator});

  final BuilderOptions options;

  /// The generator this build runs.
  final KaiselGenerator generator;

  /// Declared in the host's `build.yaml`, and it must match `kaisel.yaml: output`.
  String get _outputPath =>
      options.config['output'] as String? ?? 'lib/app/app_modules.g.dart';

  /// `$lib$` = this package's `lib/`, so the builder runs for any change under
  /// `lib/` without naming the file that carries `@KaiselInit`.
  @override
  Map<String, List<String>> get buildExtensions => {
        r'$lib$': [p.posix.relative(_outputPath, from: 'lib')],
      };

  @override
  Future<void> build(BuildStep buildStep) async {
    final packageRoot = await _packageRoot(buildStep.inputId.package);
    if (packageRoot == null) {
      log.severe('kaisel: cannot resolve the root of ${buildStep.inputId.package}');
      return;
    }

    await _declareDependencies(buildStep);

    final result = await generator.generate(
      root: packageRoot,
      write: false,
    );
    if (!result.success) {
      log.severe('kaisel: ${result.error}');
      return;
    }

    final code = result.code;
    if (code == null) {
      log.severe('kaisel: the generator returned no registry source');
      return;
    }

    final resolved = result.outputPath;
    if (resolved != null && !p.equals(resolved, p.join(packageRoot, _outputPath))) {
      log.severe(
        'kaisel: kaisel.yaml outputs `$resolved`, but this builder declares '
        '`$_outputPath`. Align them, or declare your own builder with matching '
        '`build_extensions` (see the kaisel_generator README).',
      );
      return;
    }

    await buildStep.writeAsString(
      AssetId(buildStep.inputId.package, _outputPath),
      code,
    );
    log.info(
      'kaisel: ${result.modulesCount} modules → $_outputPath in '
      '${result.elapsedDisplay}',
    );
  }

  /// Reading the host's own sources makes them inputs, so an edit re-runs this
  /// builder. Generated files are skipped: depending on them would mean
  /// depending on another builder's output, or on this one's.
  Future<void> _declareDependencies(BuildStep buildStep) async {
    final package = buildStep.inputId.package;
    for (final path in const ['pubspec.yaml', 'kaisel.yaml']) {
      try {
        await buildStep.readAsString(AssetId(package, path));
      } on Exception {
        // Not every target exposes it as an asset; the generator reads it from
        // disk either way, it just cannot invalidate on it.
      }
    }

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

  /// `package:foo/` resolves to the package's `lib/`, whose parent is its root.
  Future<String?> _packageRoot(String package) async {
    final uri = await Isolate.resolvePackageUri(Uri.parse('package:$package/'));
    if (uri == null || uri.scheme != 'file') {
      return null;
    }
    return p.normalize(Directory(uri.toFilePath()).parent.path);
  }

  /// Generated sources are not inputs: reading one would make this builder depend
  /// on another generator's output, or on its own.
  static final _generatedSuffixes = RegExp(r'\.(g|kaisel|config|cqrs)\.dart$');
}
