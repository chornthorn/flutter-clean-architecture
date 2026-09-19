import 'provider.dart';
import 'spi.dart';

/// One scope in which providers live (Keycloak: `KeycloakSession`).
///
/// A session owns the providers created for it: each one is created on first use
/// through the factory registered for its SPI, cached for the rest of the
/// session, and closed when the session closes. Nothing outside the session
/// constructs a provider.
///
/// An application implements this with whatever its providers need to see — a
/// request, a build, a resolved project. `ProviderFactory.create` hands that
/// implementation to every provider it creates.
abstract interface class ProviderSession {
  /// The provider of [spi] with [id], or the first one when [id] is `null`.
  ///
  /// Throws when the SPI has no such provider; the error type is the
  /// implementation's, since the message is only useful next to the SPIs and ids
  /// that were registered.
  T provider<T extends Provider>(Spi<T> spi, [String? id]);

  /// Every provider of [spi], in the order the SPI asks its factories.
  List<T> providers<T extends Provider>(Spi<T> spi);

  /// Closes every provider this session created.
  void close();
}
