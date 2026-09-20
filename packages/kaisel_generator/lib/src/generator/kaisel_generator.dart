import 'dart:io';

import '../generation/generation.dart';
import '../generation/host_registry.dart';
import '../generation/micro_package.dart';
import '../model/generation_result.dart';
import '../session/generation_run.dart';

/// The generator: resolve a project, scan it once, hand what it found to the
/// generation that serves it, deliver the files that generation produced.
///
/// Every stage is a named class the generator builds itself — a project scanner,
/// a library scanner with its parser, three emitters over one import emitter —
/// and each has a plain Dart interface, so a test can stand in for any of them.
///
/// This runs on the Dart VM, so the same code generates the registry for
/// `dart run kaisel_generator`, for a `build_runner` build, and for the
/// generator's own tests.
class KaiselGenerator {
  const KaiselGenerator();

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
  /// that owns generated files (the `build_runner` builder) wants. Side files are
  /// written either way: a registered package's manifest belongs to another
  /// package, and the registry cannot compile without it.
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

    // One run per call: it resolves the project, scans it once, and every file it
    // writes comes from that one scan.
    final run = GenerationRun(
      root: root,
      libDir: libDir,
      output: output,
      write: write,
    );

    try {
      final request = run.request;
      filesScanned = run.scan.filesScanned;
      filesParsed = run.scan.filesParsed;
      modulesCount = request.modules.length;

      final generated = _generationFor(run).generate(request);

      for (final file in generated.sideFiles) {
        _writeIfChanged(File(file.path), file.source, force: force);
      }
      if (write) {
        _writeIfChanged(
          File(generated.output.path),
          generated.output.source,
          force: force,
        );
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
    }
  }

  /// The generation that serves [run]: a host application, or a package that
  /// generates its own manifest.
  Generation _generationFor(GenerationRun run) => run.request.isHost
      ? HostRegistryGeneration(run)
      : MicroPackageGeneration(run);
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

int _elapsedUs(DateTime started) =>
    DateTime.now().difference(started).inMicroseconds;
