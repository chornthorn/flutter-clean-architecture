/// The project a generation session runs against, after its configuration has
/// been resolved.
///
/// The raw inputs (`--root`, `--lib`, `--output`) become these values once
/// `kaisel.yaml`, `@KaiselInit` and the conventions have had their say, so every
/// later step reads one resolved project rather than re-deriving paths.
library;

import 'kaisel_config.dart';

/// A resolved project: where its sources are, where its output goes, what it is
/// called.
class ProjectContext {
  const ProjectContext({
    required this.root,
    required this.libDir,
    required this.outputPath,
    required this.packageName,
    required this.write,
    this.config,
  });

  /// Absolute path of the project root.
  final String root;

  /// Directory the sources are scanned in.
  final String libDir;

  /// Where this run's output file goes.
  final String outputPath;

  /// The package's name, e.g. `flutter_x`.
  final String packageName;

  /// Whether the caller wants the output written, or its source handed back.
  final bool write;

  /// The project's `kaisel.yaml`, when it has one.
  final KaiselConfig? config;
}
