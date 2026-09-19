import 'provider.dart';

/// A service provider interface: one capability, its providers, and the factories
/// that create them (Keycloak: `org.keycloak.provider.Spi`).
///
/// Keycloak ties a provider class to a factory class; Dart has no `Class<T>` to
/// compare against, so a SPI carries the same information differently:
///
/// * the provider class is the type argument — `Spi<Renderer>`;
/// * the factory class is [accepts], the check Keycloak spells
///   `factory instanceof getProviderFactoryClass()`.
///
/// Registration follows from that: a factory belongs to the SPI whose [accepts]
/// answers yes, so an application registers a flat factory list and the
/// [ProviderManager] files each one under its SPI.
abstract interface class Spi<T extends Provider> {
  /// The SPI's name, e.g. `renderer`.
  String get name;

  /// Whether [factory] is a factory of this SPI.
  bool accepts(ProviderFactory<dynamic> factory);
}
