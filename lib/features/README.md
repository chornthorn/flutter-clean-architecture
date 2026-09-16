# Features

Each directory here is a self-contained feature: it owns its routes, its layers,
and its URL codec. The host app mounts it at a marker route and never learns its
internals.

See [`docs/architecture.md`](../../docs/architecture.md) for the mapping onto
the iOS reference, the rules, and why the folders are named the way they are.

## Layout

```
lib/features/<name>/
  <name>_module.dart          routes + RouteModule + URL codec, and the
                              feature's injectify micro-package where it has one
  <name>_handler.dart         the feature's CQRS module, where it has handlers
  domain/                     entities, queries and their handlers, contracts
    entities/
    usecases/
    repositories/
  infrastructure/             adapters implementing the contracts
    dtos/                     the wire shape, where one is needed
    endpoints/                the `@RestApi` calls, where there are any
    repositories/
  presentation/               Flutter UI
    views/                    one view per route
    view_models/              ChangeNotifier state, one per view
    widgets/                  reusable pieces of those views
```

`<name>_module.dart` is the feature's only entry point — the host imports
nothing else. It declares the injectify micro-package (where the feature has
registrations) and owns the routes, the `RouteModule`, and the URL codec. The
class inside is a `RouteModule` — kaisel's mountable unit — not a `KaiselRouter`.

`<name>_handler.dart` is the same kind of boundary for CQRS: an annotation and
an export, no code. A feature without handlers has no such file.

## Rules

| Folder | May import | Must not import |
|:-------|:-----------|:----------------|
| `domain/` | Plain Dart, `injectify` and `cqrs` annotations | Flutter, `get_it`, `provider.dart`, `infrastructure/`, `presentation/` |
| `infrastructure/` | `domain/`, `core/`, DI annotations, IO packages | `presentation/` |
| `presentation/` | `domain/entities/`, `core/`, `cqrs`, Flutter, `injectify` annotations | `get_it`, `provider.dart`, `infrastructure/`, `domain/repositories/` |

The router file sits outside the layers: it is pure routing plus one provider per
route, which owns the page's view model. See `docs/architecture.md`.

The `domain/` and `presentation/` rows are machine-enforced by
`test/architecture_test.dart`. `infrastructure/` is deliberately unconstrained —
it is the outermost layer and the only one allowed to talk to the outside world.

## Dependency rule

Dependencies point inward — `presentation` → `domain`, with `infrastructure`
implementing the contracts `domain/` declares and resolved by nothing but the
container.

- `domain/` is plain Dart: entities, queries and their handlers, and boundary
  contracts. No Flutter, no I/O. `cqrs` is pure Dart, so a handler is still a
  plain class.
- `infrastructure/` implements the contracts; it is the layer allowed to know
  about networks, disk, and DTOs.
- `presentation/` sends queries and commands through the injected
  `CqrsDispatcher`; it never sees a handler or a concrete repository.
- The container names a concrete implementation only through the `@Injectable`
  annotation on the class; the router resolves the graph, one line per route.
- A page reads its view model from the `ChangeNotifierProvider` the router mounts
  above it, with `context.watch`. The page imports no container and no repository;
  provider creates the view model once per mount and disposes it (factory scope —
  the container does not).
- A view model that finishes loading after its view is gone must stay silent:
  notifying a disposed `ChangeNotifier` throws. See the `_notify` guard in
  `shop/presentation/view_models/`.
- Keep the feature `const`. `KaiselModuleMount` rebuilds its router when the
  module instance changes, so a fresh instance per build would silently drop the
  feature's navigation state.

## Adding a route

1. Add a variant to the sealed type at the top of `<name>_module.dart`.
2. Handle it in the `switch` in the module below it — the compiler will already
   be reporting that switch as non-exhaustive.
3. Add a view under `presentation/views/` if the variant needs one.
4. Add the query (or command) and its handler under `domain/usecases/` if the
   view needs an interaction the feature doesn't have yet, and annotate the
   handler with `@Injectable`. A mutation that others should react to raises an
   event, which gets its own file and one handler per reaction.
5. Add both `decode` and `encode` arms to the codec at the bottom of
   `<name>_module.dart` if the route should be reachable by URL.
6. Annotate anything new that the container must build (`@Injectable`) and rerun
   `dart run build_runner build` — the CQRS module only knows the handlers it
   has seen.

## Current features

- `home/` — the app's landing screen. `presentation/` only, with a
  deliberately codec-less router: one screen has no sub-URLs, so the root path
  belongs to `BaseAppCodec` in `lib/app/`.
- `shop/` — the reference feature; every folder is in use. Read side: the catalog,
  one product, the cart, and the products in the cart. Write side: an
  `AddProductToCartCommand` whose handler raises `ProductAddedToCartEvent`, and a
  role-named handler that appends to an audit log. Routes: the list, a product,
  and the cart, which is also reachable by URL at `/shop/cart`.
- `settings/` — `presentation/` only. Its screens read no state, so `domain/`
  and `infrastructure/` would be empty ceremony; add them when the feature has
  something to load.
- `posts/` — the remote feature, and the reference for a source that is a choice:
  `infrastructure/endpoints/` holds the `@RestApi` calls, `dtos/` the wire shape,
  and `repositories/` two adapters for one contract — an HTTP one wired in `prod`
  and an in-memory fixture wired in `dev` and `test`. Reachable at `/posts`, with
  a detail route at `/posts/<id>`.
