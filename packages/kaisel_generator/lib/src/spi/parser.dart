import 'package:spi/spi.dart';

import '../model/init_info.dart';
import '../model/micro_package.dart';
import '../model/module_info.dart';

/// SPI: reading Kaisel annotations out of Dart source.
class AnnotationParserSpi implements Spi<AnnotationParser> {
  const AnnotationParserSpi();

  /// The SPI as a bootstrap registers it.
  static const instance = AnnotationParserSpi();

  @override
  String get name => 'annotation-parser';

  @override
  bool accepts(ProviderFactory<dynamic> factory) => factory is AnnotationParserFactory;
}

/// Reads Kaisel annotations out of source.
///
/// Implement this to read annotations from something other than source text —
/// resolved elements, a cache, a test double. Callers hand it the file path (for
/// the metadata it records) and the source.
abstract interface class AnnotationParser implements Provider {
  /// Reads every `@KaiselModule` class declared in [source].
  List<ModuleInfo> parseModules(String filePath, String source);

  /// Reads the `@KaiselInit` configuration [source] declares, or `null` when it
  /// declares none.
  InitInfo? parseInit(String source);

  /// Reads the `@KaiselMicroPackage` declaration [source] holds, or `null` when
  /// it holds none.
  MicroPackageDeclaration? parseMicroPackage(String filePath, String source);
}

/// Creates the [AnnotationParser] a session uses.
abstract interface class AnnotationParserFactory
    implements ProviderFactory<AnnotationParser> {}

/// SPI: reading the contract a generated micro-package manifest declares.
class ManifestParserSpi implements Spi<ManifestParser> {
  const ManifestParserSpi();

  /// The SPI as a bootstrap registers it.
  static const instance = ManifestParserSpi();

  @override
  String get name => 'manifest-parser';

  @override
  bool accepts(ProviderFactory<dynamic> factory) => factory is ManifestParserFactory;
}

/// Reads the mounts a generated manifest declares.
abstract interface class ManifestParser implements Provider {
  /// Reads the manifest [source] declares, or `null` when it was not produced by
  /// a compatible generator — the caller then reports that the manifest must be
  /// regenerated rather than composing a package that would silently contribute
  /// no mounts.
  MicroPackageManifest? parse(String source);
}

/// Creates the [ManifestParser] a session uses.
abstract interface class ManifestParserFactory implements ProviderFactory<ManifestParser> {}
