/// The generator's public API: the annotations a project writes, the result a run
/// returns, the capability SPIs a project extends the generator through, and the
/// bootstrap an entry point registers providers with.
///
/// The SPI vocabulary itself — `Spi`, `Provider`, `ProviderFactory`,
/// `ProviderSession`, `ProviderManager` — comes from `package:spi`, and is
/// deliberately *not* re-exported here: a host app imports this library next to
/// `package:provider`, and re-exporting a second `Provider` would make every such
/// import ambiguous. A file that implements an SPI imports `package:spi` itself.
///
/// Generated code imports `package:kaisel_generator/micro_mount.dart` — a
/// separate entrypoint — so this library stays the CLI's entrypoint
/// (`dart run kaisel_generator`) and imports neither kaisel nor Flutter, which a
/// plain `dart run` cannot compile.
library;

export 'src/annotations/kaisel_annotations.dart';
export 'src/generator/kaisel_generator.dart' show KaiselGenerator;
export 'src/model/generation_result.dart' show KaiselGenerationResult;
export 'src/model/init_info.dart';
export 'src/model/kaisel_config.dart';
export 'src/model/library_scan.dart';
export 'src/model/micro_package.dart';
export 'src/model/module_info.dart';
export 'src/model/project_context.dart';
export 'src/spi/bootstrap.dart';
export 'src/spi/emitter.dart';
export 'src/spi/generation.dart';
export 'src/spi/parser.dart';
export 'src/spi/scanner.dart';
export 'src/spi/session.dart';
export 'src/spi/session_factory.dart';
