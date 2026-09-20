/// The generator's public API: the annotations a project writes, the result a run
/// returns, the values it reads and writes, and the generator itself.
///
/// The interfaces a stage implements — `LibraryScanner`, `AnnotationParser`,
/// `ImportEmitter`, `RegistryEmitter`, `ManifestEmitter`, `Generation` — are
/// exported too, so a caller that wants a different stage can implement one and
/// hand it to the run.
///
/// Generated code imports `package:kaisel_generator/micro_mount.dart` — a
/// separate entrypoint — so this library stays the CLI's entrypoint
/// (`dart run kaisel_generator`) and imports neither kaisel nor Flutter, which a
/// plain `dart run` cannot compile.
library;

export 'src/annotations/kaisel_annotations.dart';
export 'src/emitter/import_emitter.dart';
export 'src/emitter/manifest_emitter.dart';
export 'src/emitter/registry_emitter.dart';
export 'src/generation/generation.dart';
export 'src/generator/kaisel_generator.dart' show KaiselGenerator;
export 'src/model/generation_result.dart' show KaiselGenerationResult;
export 'src/model/init_info.dart';
export 'src/model/kaisel_config.dart';
export 'src/model/library_scan.dart';
export 'src/model/micro_package.dart';
export 'src/model/module_info.dart';
export 'src/model/project_context.dart';
export 'src/parser/annotation_parser.dart';
export 'src/parser/manifest_parser.dart';
export 'src/scanner/library_scanner.dart';
export 'src/scanner/project_scanner.dart';
export 'src/session/generation_run.dart';
