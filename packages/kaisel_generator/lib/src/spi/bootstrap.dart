import '../emitter/default_import_emitter.dart';
import '../emitter/default_manifest_emitter.dart';
import '../emitter/default_registry_emitter.dart';
import '../generator/kaisel_generator.dart';
import '../parser/default_annotation_parser.dart';
import '../parser/default_manifest_parser.dart';
import '../provider/host_registry_provider.dart';
import '../provider/micro_package_provider.dart';
import '../scanner/default_library_scanner.dart';
import '../scanner/default_project_scanner.dart';
import 'emitter.dart';
import 'generation.dart';
import 'parser.dart';
import 'provider.dart';
import 'scanner.dart';
import 'session_factory.dart';
import 'spi.dart';

/// The composition root: the SPIs and provider factories a Kaisel entry point
/// runs.
///
/// An entry point is the one place that names concrete implementations — the
/// `build_runner` entry in `lib/builder.dart` and the CLI's `main` both start
/// here:
///
/// ```dart
/// final generator = const KaiselBootstrap().createGenerator();
/// ```
///
/// Keycloak finds SPIs and factories with the `ServiceLoader`; Dart has no
/// reflection, so [spis] and [providerFactories] are the same registration spelled
/// out — Kaisel's own by default. Register a provider of your own by adding its
/// factory to [providerFactories] (and a new SPI to [spis] if it is a new
/// capability); it takes precedence over a built-in provider by registering a
/// lower [ProviderFactory.order].
class KaiselBootstrap {
  const KaiselBootstrap({
    this.spis = kaiselSpis,
    this.providerFactories = kaiselProviderFactories,
  });

  /// The SPIs a session factory knows.
  final List<Spi<dynamic>> spis;

  /// The provider factories registered for them.
  final List<ProviderFactory<dynamic>> providerFactories;

  /// The session factory an entry point runs sessions with.
  KaiselSessionFactory createSessionFactory() =>
      KaiselSessionFactory(spis: spis, factories: providerFactories);

  /// The generator this bootstrap's entry point runs.
  KaiselGenerator createGenerator() =>
      KaiselGenerator(sessionFactory: createSessionFactory());
}

/// The SPIs Kaisel ships (Keycloak: the `Spi` service file).
const kaiselSpis = <Spi<dynamic>>[
  LibraryScannerSpi.instance,
  ProjectScannerSpi.instance,
  AnnotationParserSpi.instance,
  ManifestParserSpi.instance,
  ImportEmitterSpi.instance,
  RegistryEmitterSpi.instance,
  ManifestEmitterSpi.instance,
  GenerationSpi.instance,
];

/// The provider factories Kaisel ships (Keycloak: the `ProviderFactory` service
/// file), most specific provider first within each SPI.
const kaiselProviderFactories = <ProviderFactory<dynamic>>[
  DefaultProjectScannerFactory(),
  DefaultAnnotationParserFactory(),
  DefaultManifestParserFactory(),
  DefaultImportEmitterFactory(),
  DefaultLibraryScannerFactory(),
  DefaultRegistryEmitterFactory(),
  DefaultManifestEmitterFactory(),
  HostRegistryProviderFactory(),
  MicroPackageProviderFactory(),
];
