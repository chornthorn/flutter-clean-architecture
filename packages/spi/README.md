# spi

A service-provider-interface (SPI) framework for Dart — the provider/factory
standard behind [Keycloak's SPI](https://www.keycloak.org/docs/latest/server_development/#_providers),
with Dart's lack of reflection taken into account.

One capability is one `Spi`; a `Provider` implements it; a `ProviderFactory`
creates providers for a `ProviderSession`; a `ProviderManager` files each factory
under the SPI that accepts it.

```dart
class RendererSpi implements Spi<Renderer> {
  const RendererSpi();
  static const instance = RendererSpi();

  @override
  String get name => 'renderer';

  @override
  bool accepts(ProviderFactory<dynamic> factory) => factory is RendererFactory;
}

/// The capability's contract.
abstract interface class Renderer implements Provider {
  String render(String source);
}

/// The marker that ties factories to [RendererSpi].
abstract interface class RendererFactory implements ProviderFactory<Renderer> {}

class SvgRenderer implements Renderer {
  const SvgRenderer();

  @override
  void close() {}

  @override
  String render(String source) => '<svg>$source</svg>';
}

class SvgRendererFactory implements RendererFactory {
  const SvgRendererFactory();

  @override
  String get id => 'svg';

  @override
  int get order => defaultProviderOrder;

  @override
  Renderer create(ProviderSession session) => const SvgRenderer();
}
```

## What the framework does

| Piece               | Role                                                                                                                                               |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Spi<T>`            | Names a capability. `accepts(factory)` binds a factory to it — Dart's stand-in for Keycloak's `getProviderFactoryClass()`.                         |
| `Provider`          | A service scoped to one session. Closed by the session that created it.                                                                            |
| `ProviderFactory`   | Creates providers. Holds no dependencies of its own: it is handed the session.                                                                     |
| `ProviderManager`   | Files the registered factories under their SPIs and resolves them — by SPI, and by id. `order` decides precedence, registration order breaks ties. |
| `ProviderSession`   | The scope providers live in. Implement it with whatever the providers need to see — a request, a build, a resolved project.                        |
| `ProviderException` | A factory no SPI accepts: a wiring bug reported at composition time.                                                                               |

## Why not a `ServiceLoader`

Keycloak finds SPIs and factories by reading `META-INF/services` files at
runtime. Dart has no reflection and no service loader, so the same registration
is written out where the application composes itself:

```dart
final manager = ProviderManager(
  spis: [RendererSpi.instance],
  factories: [const SvgRendererFactory()],
);
```

The interface is explicit instead of discovered — which also means a factory that
belongs to no SPI is caught when the manager is built, not when it is first used.

## Design notes

- **No dependencies.** The package imports nothing. A package that implements an
  SPI depends on this one and nothing else — no code generator, no framework.
- **The vocabulary is the SPI's.** A capability's names (`Renderer`,
  `RendererFactory`) are the SPI author's; this package only supplies the shape
  they hang on.
- **`ProviderManager` is the default manager, not the only one.** A session that
  resolves providers differently implements `ProviderSession` and can skip the
  manager entirely.
