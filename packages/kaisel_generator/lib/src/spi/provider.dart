import 'session.dart';

/// The order Kaisel's own providers register with.
///
/// A provider that must be asked before a built-in one registers a lower order,
/// so taking precedence does not mean reordering the bootstrap's factory list.
const int kaiselProviderOrder = 100;

/// A service created by a [ProviderFactory] and scoped to one session.
///
/// Keycloak's `org.keycloak.provider.Provider`: the session creates providers on
/// demand and closes them when the session ends. Every capability in this package
/// — a scanner, a parser, an emitter, a generation provider — is a `Provider`.
abstract interface class Provider {
  /// Releases anything this provider holds.
  ///
  /// Called by the session that created it; the built-in providers hold nothing,
  /// so they have nothing to release.
  void close();
}

/// Creates the providers of one SPI (Keycloak:
/// `org.keycloak.provider.ProviderFactory`).
///
/// One factory per provider, and — as in Keycloak — the factory holds no
/// dependencies: it is handed the session, and the provider takes what it needs
/// from there.
abstract interface class ProviderFactory<T extends Provider> {
  /// The id this factory registers under, e.g. `default`.
  ///
  /// Ids are what a caller asks for a specific implementation by, and what the
  /// session lists when an SPI has no provider to serve a request.
  String get id;

  /// Where this factory sits among its SPI's factories, lowest first
  /// (Keycloak: `order()`).
  ///
  /// A provider that must be asked before the built-in ones registers a lower
  /// order instead of reordering the bootstrap's list.
  int get order;

  /// Creates a provider for [session].
  T create(KaiselSession session);
}
