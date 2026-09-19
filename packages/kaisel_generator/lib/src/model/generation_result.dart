/// What a generation run produced, and the failure it raises when it cannot
/// produce one.
library;

/// What a generation run produced.
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

  String get elapsedDisplay =>
      elapsedUs >= 1000 ? '${(elapsedUs / 1000).toStringAsFixed(1)} ms' : '$elapsedUs µs';
}

/// Raised inside the generator when a run cannot proceed;
/// [KaiselGenerator.generate] turns it into a failed [KaiselGenerationResult].
class KaiselGenerationException implements Exception {
  const KaiselGenerationException(this.message);

  final String message;

  @override
  String toString() => message;
}
