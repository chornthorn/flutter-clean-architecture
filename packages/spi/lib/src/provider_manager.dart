import 'provider.dart';
import 'provider_exception.dart';
import 'provider_session.dart';
import 'spi.dart';

/// The factories registered for each SPI (Keycloak: `DefaultProviderManager`).
///
/// Keycloak finds factories with the `ServiceLoader`; Dart has no reflection, so
/// a composition root hands the manager the factory list explicitly — the same
/// registration, spelled out. A factory belongs to exactly one SPI, and a factory
/// no SPI accepts is a registration bug, not a silent no-op.
class ProviderManager {
  ProviderManager({
    required Iterable<Spi<dynamic>> spis,
    required Iterable<ProviderFactory<dynamic>> factories,
  }) : spis = List.unmodifiable(spis) {
    // The order an SPI asks its factories in is `order`, then registration
    // order — so insert at the first factory this one outranks rather than
    // sorting afterwards, since Dart's `List.sort` is not stable.
    for (final factory in factories) {
      final spi = spiOf(factory);
      if (spi == null) {
        final registered = this.spis.map((spi) => spi.name).join(', ');
        throw ProviderException(
          'No SPI accepts the provider factory `${factory.id}`. '
          'Registered SPIs: $registered.',
        );
      }
      final registered = _factoriesForSpi.putIfAbsent(spi.name, () => []);
      final at = registered.indexWhere((existing) => existing.order > factory.order);
      if (at == -1) {
        registered.add(factory);
      } else {
        registered.insert(at, factory);
      }
    }
  }

  /// The SPIs registered with this manager.
  final List<Spi<dynamic>> spis;

  final Map<String, List<ProviderFactory<dynamic>>> _factoriesForSpi = {};
  final Map<String, Provider> _shared = {};

  /// The application-scoped provider for [factory], created on the first ask and
  /// handed to every session until [close].
  ///
  /// Keycloak: the singleton `Provider` implementations a factory caches — except
  /// that here the manager owns the lifetime, so no session can close one out from
  /// under another.
  Provider shared(
    Spi<dynamic> spi,
    ProviderFactory<dynamic> factory,
    ProviderSession session,
  ) =>
      _shared.putIfAbsent('${spi.name}/${factory.id}', () => factory.create(session));

  /// Closes the application-scoped providers. The application calls this on
  /// teardown; a session must never close what it does not own.
  void close() {
    for (final provider in _shared.values) {
      provider.close();
    }
    _shared.clear();
  }

  /// The SPI [factory] belongs to, or `null` when no registered SPI accepts it.
  Spi<dynamic>? spiOf(ProviderFactory<dynamic> factory) {
    for (final spi in spis) {
      if (spi.accepts(factory)) {
        return spi;
      }
    }
    return null;
  }

  /// The factories registered for [spi], ordered.
  List<ProviderFactory<dynamic>> factoriesFor(Spi<dynamic> spi) =>
      List.unmodifiable(_factoriesForSpi[spi.name] ?? const []);

  /// The factory for [spi] with [id], or the first one when [id] is `null`.
  ///
  /// Keycloak's `KeycloakSession.getProvider(Class<T>, String id)`: the cast is
  /// sound because [Spi.accepts] tied the factory to this SPI's provider class.
  ProviderFactory<T>? factoryFor<T extends Provider>(Spi<T> spi, [String? id]) {
    for (final factory in _factoriesForSpi[spi.name] ?? const <ProviderFactory<dynamic>>[]) {
      if (id == null || factory.id == id) {
        return factory as ProviderFactory<T>;
      }
    }
    return null;
  }
}
