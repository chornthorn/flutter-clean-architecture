import 'dart:io';

import '../model/generation_result.dart';
import '../spi/generation.dart';
import '../spi/session.dart';
import '../spi/session_factory.dart';

/// The generator: open a session for a project, hand what it found to the
/// generation provider that serves it, deliver the files that provider produced.
///
/// The pipeline is fixed and the output is open: what gets generated for a
/// project, and where it goes, is the business of a [GenerationProvider]. The
/// provider itself comes from the session, which creates it through the factory
/// the entry point registered.
///
/// This runs on the Dart VM, so the same code generates the registry for
/// `dart run kaisel_generator`, for a `build_runner` build, and for the
/// generator's own tests.
class KaiselGenerator {
  const KaiselGenerator({required this.sessionFactory});

  /// The sessions this generator runs, wired by a `KaiselBootstrap`.
  final KaiselSessionFactory sessionFactory;

  /// Generates the output of the project at [root] — the host's `AppRoute`
  /// hierarchy and everything composed into it, or a micro-package's manifest
  /// when the project declares one.
  ///
  /// [root] defaults to the project containing the working directory. [libDir]
  /// and [output] override `kaisel.yaml`, which overrides `@KaiselInit`, which
  /// overrides the conventions (`lib/`, `lib/app/app_modules.g.dart`).
  ///
  /// Set [write] to `false` to get the output's source back in
  /// [KaiselGenerationResult.code] instead of having it written — what a caller
  /// that owns generated files (the `build_runner` builder) wants. Side files a
  /// provider produced are written either way: a registered package's manifest
  /// belongs to another package, and the registry cannot compile without it.
  ///
  /// [force] rewrites every generated file, including one whose contents did not
  /// change.
  Future<KaiselGenerationResult> generate({
    String? root,
    String? libDir,
    String? output,
    bool force = false,
    bool write = true,
  }) async {
    final started = DateTime.now();
    var filesScanned = 0;
    var filesParsed = 0;
    var modulesCount = 0;

    // One session per run: it resolves the project, scans it once, and owns every
    // provider the run uses.
    final session = sessionFactory.createSession(
      root: root,
      libDir: libDir,
      output: output,
      write: write,
    );

    try {
      final request = session.request;
      filesScanned = session.scan.filesScanned;
      filesParsed = session.scan.filesParsed;
      modulesCount = request.modules.length;

      final generated = _providerFor(session, request).generate(request);

      for (final file in generated.sideFiles) {
        _writeIfChanged(File(file.path), file.source, force: force);
      }
      if (write) {
        _writeIfChanged(File(generated.output.path), generated.output.source, force: force);
      }

      return KaiselGenerationResult(
        success: true,
        filesScanned: filesScanned,
        filesParsed: filesParsed,
        modulesCount: modulesCount,
        elapsedUs: _elapsedUs(started),
        outputPath: generated.output.path,
        code: write ? null : generated.output.source,
      );
    } on KaiselGenerationException catch (error) {
      return KaiselGenerationResult(
        success: false,
        error: error.message,
        filesScanned: filesScanned,
        filesParsed: filesParsed,
        modulesCount: modulesCount,
        elapsedUs: _elapsedUs(started),
      );
    } finally {
      session.close();
    }
  }

  /// The generation provider that serves [request]: the first one the session
  /// creates for the generation SPI whose `supports` says yes.
  GenerationProvider _providerFor(KaiselSession session, GenerationRequest request) {
    for (final provider in session.providers(GenerationSpi.instance)) {
      if (provider.supports(request)) {
        return provider;
      }
    }

    final registered = session.providerManager
        .factoriesFor(GenerationSpi.instance)
        .map((factory) => factory.id)
        .join(', ');
    throw KaiselGenerationException(
      'No Kaisel generation provider serves `${request.root}`: it declares no '
      '`@KaiselInit`, `kaisel.yaml` or `@KaiselMicroPackage`. '
      'Registered providers: $registered.',
    );
  }
}

/// Writes [content] to [file] unless it is already exactly there, so a run that
/// changes nothing does not touch the file.
void _writeIfChanged(File file, String content, {required bool force}) {
  if (!force && file.existsSync() && file.readAsStringSync() == content) {
    return;
  }

  try {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  } on FileSystemException catch (error) {
    throw KaiselGenerationException(
      'Could not write `${file.path}`: ${error.message}',
    );
  }
}

int _elapsedUs(DateTime started) => DateTime.now().difference(started).inMicroseconds;
