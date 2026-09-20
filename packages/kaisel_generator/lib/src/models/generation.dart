/// What a run is asked for, what a generation produces, and how a run ends.
library;

import 'config.dart';
import 'scan.dart';

/// What a generation run produced, and the failure it raises when it cannot
/// produce one.
///
/// A failed run carries the reason in [error] rather than throwing, so the CLI
/// can exit non-zero with it and a `build_runner` builder can log it.
class KaiselGenerationResult {
  const KaiselGenerationResult({
    required this.success,
    this.error,
    this.filesScanned = 0,
    this.filesParsed = 0,
    this.modulesCount = 0,
    this.elapsedUs = 0,
    this.outputPath,
    this.code,
  });

  final bool success;

  /// Why the run failed, or `null` when it succeeded.
  final String? error;

  /// `.dart` files under `lib/` the scan considered.
  final int filesScanned;

  /// Files that contained an annotation the scan had to read.
  final int filesParsed;

  /// `@KaiselModule` classes found.
  final int modulesCount;

  final int elapsedUs;

  /// Path of the generated registry (or of the manifest, for a micro-package).
  final String? outputPath;

  /// The registry source, when the caller owns the output file and asked for the
  /// source instead of having it written.
  final String? code;

  String get elapsedDisplay => elapsedUs >= 1000
      ? '${(elapsedUs / 1000).toStringAsFixed(1)} ms'
      : '$elapsedUs µs';
}

/// Raised inside a run when it cannot proceed; `KaiselGenerator.generate` turns it
/// into a failed [KaiselGenerationResult].
class KaiselGenerationException implements Exception {
  const KaiselGenerationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Everything a generation needs: the project it was asked about, and what the
/// scan of that project found.
class GenerationRequest {
  const GenerationRequest({
    required this.root,
    required this.libDir,
    required this.outputPath,
    required this.modules,
    required this.packageName,
    this.config,
    this.init,
    this.write = true,
  });

  /// Absolute path of the project root.
  final String root;

  /// Directory the modules were scanned from.
  final String libDir;

  /// Where this run's output file goes.
  final String outputPath;

  /// The `@KaiselModule` classes found, sorted: initial landing module first,
  /// then by mount name.
  final List<ModuleInfo> modules;

  /// The package's name, e.g. `flutter_x`.
  final String packageName;

  /// The project's `kaisel.yaml`, when it has one.
  final KaiselConfig? config;

  /// The project's `@KaiselInit` entry point, when it declares one.
  final InitInfo? init;

  /// Whether the caller wants the output written. `false` hands the output's
  /// source back instead — what a caller that owns generated files
  /// (the `build_runner` builder) asks for.
  final bool write;

  /// Whether this project is a host application: it configures routing through
  /// `@KaiselInit` or `kaisel.yaml`, rather than being a micro-package.
  bool get isHost => init != null || config != null;
}

/// What a generation produced.
class GeneratedOutput {
  const GeneratedOutput({required this.output, this.sideFiles = const []});

  /// The run's output file: the one reported as the result's `outputPath`, and
  /// the one handed back when the request asked for a source instead of a write.
  final GeneratedFile output;

  /// Files the output needs on disk, written by the generator either way.
  ///
  /// A registered package's manifest is the example: it belongs to *another*
  /// package, and the registry cannot compile until it exists — but it is not
  /// what this run reports as its output.
  final List<GeneratedFile> sideFiles;
}

/// One generated file.
class GeneratedFile {
  const GeneratedFile({required this.path, required this.source});

  /// Absolute path the file is written to.
  final String path;

  /// The file's source.
  final String source;
}
