/// The generator's public API: the annotations a project writes, the values it
/// reads and writes, the stages it runs, and the generator itself.
///
/// The stages are exported with their interfaces, so a caller that wants a
/// different scanner, parser or emitter can implement one and use it directly.
///
/// Generated code imports `package:kaisel_generator/micro_mount.dart` — a separate
/// entrypoint — so this library stays the CLI's entrypoint
/// (`dart run kaisel_generator`) and imports neither kaisel nor Flutter, which a
/// plain `dart run` cannot compile.
library;

export 'src/annotation/kaisel_annotations.dart';
export 'src/helper/naming.dart';
export 'src/models/config.dart';
export 'src/models/generation.dart';
export 'src/models/scan.dart';
export 'src/service/annotation_parser.dart';
export 'src/service/emitters.dart';
export 'src/service/generation.dart' show GenerationRun, KaiselGenerator;
export 'src/service/library_scanner.dart';
export 'src/service/manifest_parser.dart';
export 'src/service/project_scanner.dart';
export 'src/service/registry_emitter.dart';
