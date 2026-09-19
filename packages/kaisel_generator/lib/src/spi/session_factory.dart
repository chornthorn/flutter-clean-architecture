import 'package:spi/spi.dart';

import 'session.dart';

/// Creates sessions and holds the factories they run (Keycloak:
/// `KeycloakSessionFactory`).
///
/// One session factory per entry point: the bootstrap registers the SPIs and
/// provider factories, this creates a session per generation run, and the run's
/// providers all come from the factories registered here.
class KaiselSessionFactory {
  KaiselSessionFactory({
    required Iterable<Spi<dynamic>> spis,
    required Iterable<ProviderFactory<dynamic>> factories,
  }) : providerManager = ProviderManager(spis: spis, factories: factories);

  final ProviderManager providerManager;

  /// The SPIs registered with this factory.
  List<Spi<dynamic>> get spis => providerManager.spis;

  /// The factories registered for [spi], in the order it asks them.
  List<ProviderFactory<dynamic>> factoriesFor(Spi<dynamic> spi) =>
      providerManager.factoriesFor(spi);

  /// A session for one generation run.
  KaiselSession createSession({
    String? root,
    String? libDir,
    String? output,
    bool write = true,
  }) =>
      KaiselSession(
        providerManager: providerManager,
        root: root,
        libDir: libDir,
        output: output,
        write: write,
      );
}
