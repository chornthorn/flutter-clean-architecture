import 'provider_session.dart';

/// The order a framework's own providers register with.
///
/// A provider that must be asked before the built-in ones registers a lower
/// order, so taking precedence does not mean reordering the composition root's
/// factory list.
const int defaultProviderOrder = 100;

/// A service created by a [ProviderFactory] and scoped to one session
/// (Keycloak: `org.keycloak.provider.Provider`).
///
/// Every capability behind an SPI is a provider: the session creates it on
/// demand through a factory, and closes it when the session ends.
abstract interface class Provider {
  /// Releases anything this provider holds.
  ///
  /// Called by the session that created it. A provider that holds nothing has
  /// nothing to release.
  void close();
}

/// How long a provider lives.
///
/// Keycloak leaves this implicit — a factory that shares one instance across
/// sessions must make `close()` a no-op — which is a quiet way to close a
/// connection pool a screen still needed. Here it is declared, and the session
/// honours it.
enum ProviderScope {
  /// Created with the session that asked for it, and closed when it closes.
  session,

  /// Created once per manager, shared by every session, closed by the manager.
  ///
  /// The factory must return the same instance for every session and keep no
  /// session state in it: whichever session asked first is not the owner.
  application,
}

/// Creates the providers of one SPI (Keycloak:
/// `org.keycloak.provider.ProviderFactory`).
///
/// One factory per provider, and — as in Keycloak — the factory holds no
/// dependencies of its own: it is handed the session, and the provider takes what
/// it needs from there.
abstract interface class ProviderFactory<T extends Provider> {
  /// The id this factory registers under, e.g. `default`.
  ///
  /// Ids are what a caller asks for a specific implementation by, and what the
  /// session lists when an SPI has no provider to serve a request.
  String get id;

  /// Where this factory sits among its SPI's factories, lowest first
  /// (Keycloak: `order()`).
  ///
  /// Ties keep registration order. A provider that must be asked before the
  /// built-in ones registers a lower order — for framework providers that is
  /// [defaultProviderOrder].
  int get order;

  /// How long the providers this factory creates live.
  ProviderScope get scope;

  /// Creates a provider for [session].
  T create(ProviderSession session);
}
