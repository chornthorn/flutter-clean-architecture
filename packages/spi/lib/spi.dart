/// A service-provider-interface (SPI) framework for Dart.
///
/// One capability is one [Spi]; a [Provider] implements it; a [ProviderFactory]
/// creates providers for a [ProviderSession]; a [ProviderManager] files each
/// factory under the SPI that accepts it.
///
/// ```dart
/// // The capability: its SPI, its contract, and the marker its factories carry.
/// class RendererSpi implements Spi<Renderer> {
///   const RendererSpi();
///   static const instance = RendererSpi();
///
///   @override
///   String get name => 'renderer';
///
///   @override
///   bool accepts(ProviderFactory<dynamic> factory) => factory is RendererFactory;
/// }
///
/// abstract interface class Renderer implements Provider {
///   String render(String source);
/// }
///
/// abstract interface class RendererFactory implements ProviderFactory<Renderer> {}
///
/// // One implementation.
/// class SvgRenderer implements Renderer {
///   const SvgRenderer();
///
///   @override
///   void close() {}
///
///   @override
///   String render(String source) => '<svg>$source</svg>';
/// }
///
/// class SvgRendererFactory implements RendererFactory {
///   const SvgRendererFactory();
///
///   @override
///   String get id => 'svg';
///
///   @override
///   int get order => defaultProviderOrder;
///
///   @override
///   Renderer create(ProviderSession session) => const SvgRenderer();
/// }
/// ```
///
/// Registration is explicit — Dart has no `ServiceLoader` to read a service file
/// from, so the factories are listed where the application composes itself:
///
/// ```dart
/// final manager = ProviderManager(
///   spis: [RendererSpi.instance],
///   factories: [const SvgRendererFactory()],
/// );
/// ```
library;

export 'src/default_provider_session.dart';
export 'src/provider.dart';
export 'src/provider_exception.dart';
export 'src/provider_manager.dart';
export 'src/provider_session.dart';
export 'src/spi.dart';
