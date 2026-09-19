import 'provider.dart';
import 'provider_exception.dart';
import 'provider_manager.dart';
import 'provider_session.dart';
import 'spi.dart';

/// The create-once / cache-by-`spi/id` / close-what-this-session-created loop
/// every session needs (Keycloak: `DefaultKeycloakSession`).
///
/// A session creates a provider on first ask and caches it for its lifetime; at
/// [close] it releases what it created, innermost first. Application-scoped
/// providers are not the session's to close — the [ProviderManager] owns them.
///
/// The session is what makes a provider graph request-scoped: an application that
/// has per-request context (a build, a screen, an HTTP request) implements
/// `ProviderSession` by extending this class and adding that context, rather than
/// rewriting the loop.
class DefaultProviderSession implements ProviderSession {
  DefaultProviderSession({required this.providerManager});

  /// The registration this session resolves providers through.
  final ProviderManager providerManager;

  final Map<String, Provider> _created = {};

  /// The ids this session has already created, in creation order — what [close]
  /// releases and what a test asserts is empty.
  Iterable<String> get created => List.unmodifiable(_created.keys);

  @override
  T provider<T extends Provider>(Spi<T> spi, [String? id]) {
    final factory = providerManager.factoryFor(spi, id);
    if (factory == null) {
      throw ProviderException(
        'No provider of `${spi.name}`'
        '${id == null ? '' : ' under id `$id`'} is registered.',
      );
    }

    if (factory.scope == ProviderScope.application) {
      return providerManager.shared(spi, factory, this) as T;
    }

    return _created.putIfAbsent(
      '${spi.name}/${factory.id}',
      () => factory.create(this),
    ) as T;
  }

  @override
  List<T> providers<T extends Provider>(Spi<T> spi) => [
        for (final factory in providerManager.factoriesFor(spi)) provider(spi, factory.id),
      ];

  /// Closes every provider this session created, innermost first: a provider that
  /// was created after another may depend on it.
  @override
  void close() {
    final created = _created.values.toList().reversed;
    _created.clear();
    for (final provider in created) {
      provider.close();
    }
  }
}
