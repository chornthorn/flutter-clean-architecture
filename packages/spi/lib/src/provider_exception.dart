/// A provider could not be registered: no SPI accepts its factory.
///
/// Registration is composition, so this is a bug in an application's wiring
/// rather than a runtime condition — the message names the SPIs that were
/// registered, because the missing one is usually a factory that was never
/// listed or a typo in a factory's `implements` clause.
class ProviderException implements Exception {
  const ProviderException(this.message);

  final String message;

  @override
  String toString() => message;
}
