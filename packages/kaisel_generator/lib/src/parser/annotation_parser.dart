import '../model/init_info.dart';
import '../model/micro_package.dart';
import '../model/module_info.dart';

/// Reads Kaisel annotations out of source.
///
/// The generator's default reads Dart source text; a test that needs a fixture
/// implements this instead. Callers hand it the file path (for the metadata it
/// records) and the source.
abstract interface class AnnotationParser {
  /// Reads every `@KaiselModule` class declared in [source].
  List<ModuleInfo> parseModules(String filePath, String source);

  /// Reads the `@KaiselInit` configuration [source] declares, or `null` when it
  /// declares none.
  InitInfo? parseInit(String source);

  /// Reads the `@KaiselMicroPackage` declaration [source] holds, or `null` when
  /// it holds none.
  MicroPackageDeclaration? parseMicroPackage(String filePath, String source);
}
