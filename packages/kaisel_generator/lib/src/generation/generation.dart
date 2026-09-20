import '../model/generation_result.dart';
import '../model/init_info.dart';
import '../model/kaisel_config.dart';
import '../model/module_info.dart';

/// Generates the files a project needs from what its scan found.
///
/// One implementation serves one kind of project: `HostRegistryGeneration` a host
/// application, `MicroPackageGeneration` a package that generates its own manifest.
/// `KaiselGenerator` picks between them on [GenerationRequest.isHost].
abstract interface class Generation {
  /// Produces the files for [request].
  ///
  /// Throws a [KaiselGenerationException] when the request cannot be served; the
  /// generator turns that into a failed [KaiselGenerationResult].
  GeneratedOutput generate(GenerationRequest request);
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
