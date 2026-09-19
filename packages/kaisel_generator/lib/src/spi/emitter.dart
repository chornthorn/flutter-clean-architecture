import '../model/micro_package.dart';
import '../model/module_info.dart';
import 'provider.dart';
import 'spi.dart';

/// SPI: emitting the import block a generated file opens with.
class ImportEmitterSpi implements Spi<ImportEmitter> {
  const ImportEmitterSpi();

  /// The SPI as a session factory registers it.
  static const instance = ImportEmitterSpi();

  @override
  String get name => 'import-emitter';

  @override
  bool accepts(ProviderFactory<dynamic> factory) => factory is ImportEmitterFactory;
}

/// Writes the imports a generated file opens with.
///
/// Implement this to change how generated files import what they compose — a
/// different alias scheme, relative imports, a fixed header.
abstract interface class ImportEmitter implements Provider {
  /// The aliases for [keys], numbered `1..n` in the order given.
  Map<String, String> aliasesFor(List<String> keys, String prefix);

  /// Writes `import '<uri>' as <alias>;` for each of [aliasedImports].
  void writeImports(
    StringBuffer buffer,
    List<({String uri, String alias})> aliasedImports,
  );

  /// A `package:` import for a file inside the package.
  String packageUri({
    required String packageName,
    required String libDir,
    required String file,
  });
}

/// Creates the [ImportEmitter] a session uses.
abstract interface class ImportEmitterFactory implements ProviderFactory<ImportEmitter> {}

/// SPI: emitting the host's module registry.
class RegistryEmitterSpi implements Spi<RegistryEmitter> {
  const RegistryEmitterSpi();

  /// The SPI as a session factory registers it.
  static const instance = RegistryEmitterSpi();

  @override
  String get name => 'registry-emitter';

  @override
  bool accepts(ProviderFactory<dynamic> factory) => factory is RegistryEmitterFactory;
}

/// Writes the sealed route hierarchy, the page builder, the URL mounts and the
/// router config an app runs on.
abstract interface class RegistryEmitter implements Provider {
  /// Writes the registry for a project whose modules are [modules] and whose
  /// composed micro-packages are [microPackages].
  String write({
    required List<ModuleInfo> modules,
    required String routeClass,
    required String? initialRouteOverride,
    required List<MicroPackageInfo> microPackages,
    required String packageName,
    required String libDir,
  });
}

/// Creates the [RegistryEmitter] a session uses.
abstract interface class RegistryEmitterFactory implements ProviderFactory<RegistryEmitter> {}

/// SPI: emitting a micro-package manifest.
class ManifestEmitterSpi implements Spi<ManifestEmitter> {
  const ManifestEmitterSpi();

  /// The SPI as a session factory registers it.
  static const instance = ManifestEmitterSpi();

  @override
  String get name => 'manifest-emitter';

  @override
  bool accepts(ProviderFactory<dynamic> factory) => factory is ManifestEmitterFactory;
}

/// Writes one registry class declaring what a micro-package contributes, for a
/// host to bind to its own marker routes.
abstract interface class ManifestEmitter implements Provider {
  /// Writes the manifest of the package module named [moduleName].
  String write({
    required String moduleName,
    required List<ModuleInfo> modules,
    required String packageName,
    required String libDir,
    required String? basePrefix,
  });
}

/// Creates the [ManifestEmitter] a session uses.
abstract interface class ManifestEmitterFactory implements ProviderFactory<ManifestEmitter> {}
