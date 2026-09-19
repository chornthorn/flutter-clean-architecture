/// The generator's public API: the annotations a project writes, the result a
/// run returns, and [KaiselGenerator] itself.
///
/// Generated code imports `package:kaisel_generator/micro_mount.dart` — a
/// separate entrypoint — so this library stays the CLI's entrypoint
/// (`dart run kaisel_generator`) and imports neither kaisel nor Flutter, which a
/// plain `dart run` cannot compile.
library;

export 'src/annotations/kaisel_annotations.dart';
export 'src/generator/kaisel_generator.dart' show KaiselGenerator;
export 'src/model/generation_result.dart' show KaiselGenerationResult;
