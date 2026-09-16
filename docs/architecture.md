# Architecture

Three top-level areas — `app/`, `core/`, `features/` — and three layers inside
each feature: Presentation, Domain, Infrastructure. Dependencies point inward.

The layout is a direct transcription of the iOS reference (`App/`, `Core/`,
`Features/<Feature>/{Presentation,Domain,Infrastructure}`) onto Flutter. The
mapping is below so nobody has to guess where a new file belongs.

Read this before restructuring. Several choices here differ from the common
Flutter clean-architecture template, and each one is deliberate.

## Layout

```
lib/
  main.dart
  provider.dart                      the container + @CqrsInit, the app's composition
  provider.config.dart               generated — do not edit
  provider.cqrs.dart                 generated — do not edit
  app/                               app-level setup and composition
    app.dart                         MaterialApp.router + theme + the router config
    app_route.dart                   the host's sealed route family
    app_page_builder.dart            marker route -> feature mount
    app_codec.dart                   host URL codec + module mounts
  core/                              shared foundation (see core/README.md)
    design_system/
      theme-spec.schema.json
      app.tokens.json                the token values, per mode
      app_theme.g.dart               generated — do not edit
  features/
    <name>/
      <name>_module.dart        routes + RouteModule + URL codec + DI module
      <name>_handler.dart       the feature's CQRS module, where it has handlers
      domain/                   entities, queries and their handlers, contracts
      infrastructure/           adapters implementing the contracts
      presentation/             views, view models, widgets
```

## Mapping from the iOS reference

| iOS (CRMApp) | Flutter here | Notes |
|:-------------|:-------------|:------|
| `App/AppDelegate.swift` | `lib/main.dart`, `lib/app/app.dart` | Entry point and root widget. |
| `App/AppCoordinator.swift` | `lib/app/app_route.dart`, `app_page_builder.dart`, plus each `features/<name>/<name>_module.dart` | Kaisel supplies the coordination machinery. Each feature owns a router because a kaisel `RouteModule` is the mountable unit — there is no single app-level coordinator. |
| `App/DependencyContainer.swift` | `lib/provider.dart`, plus `features/<name>/<name>_module.dart` | `injectify` + `get_it`: one root container that composes a folder-scoped micro-package per feature. A feature's registrations are reachable only through its own module. Kept at the `lib/` root rather than inside `app/` so a feature's module does not import the app layer. It also carries `@CqrsInit`, so the app's composition sits in one file. |
| `Core/DesignSystem/` | `lib/core/design_system/` | Tokens (`app.tokens.json`) compiled to `app_theme.g.dart` by `design_builder`. `components/` arrives with the second feature needing the same control. |
| `Core/Networking/` | `lib/core/networking/` | Not created — no HTTP call exists yet. |
| `Core/Storage/` | `lib/core/storage/` | Not created — nothing is persisted yet. |
| `Features/Leads/Presentation/Views/` | `features/<name>/presentation/views/` | `LeadListView.swift` → `shop_home_view.dart`. |
| `.../Presentation/ViewModels/` | `presentation/view_models/` | `ChangeNotifier`s, one per view. |
| `.../Domain/Entities/` | `domain/entities/` | |
| `.../Domain/UseCases/` | `domain/usecases/` | A use case is a query (or command) plus its handler, in one file. Both live in Domain — there is no separate application layer. |
| `.../Domain/Repositories/` | `domain/repositories/` | The interface definition; the concrete type goes in Infrastructure. |
| `.../Infrastructure/DTOs/` | `infrastructure/dtos/` | Not created — no response differs from an entity yet. |
| `.../Infrastructure/Endpoints/` | `infrastructure/endpoints/` | Not created — no endpoints yet. |
| `.../Infrastructure/Repositories/` | `infrastructure/repositories/` | The concrete implementation. |

## Rules

| Folder | May import | Must not import |
|:-------|:-----------|:----------------|
| `core/` | Flutter, packages | `features/` |
| `features/*/domain/` | Plain Dart, `injectify` and `cqrs` annotations | Flutter, `get_it`, `provider.dart`, `infrastructure/`, `presentation/` |
| `features/*/infrastructure/` | `domain/`, `core/`, DI annotations, IO packages | `presentation/` |
| `features/*/presentation/` | `domain/entities/`, `core/`, `cqrs`, Flutter, `injectify` annotations | `get_it`, `provider.dart`, `infrastructure/`, `domain/repositories/` |

`<name>_module.dart` sits outside the layers: it is pure routing plus the
feature's DI boundary. Wiring happens through the container — see below — so no
file constructs an `infrastructure/` class by hand.

## Where new code goes

- **A new screen** → sealed route in `<name>_module.dart`, a view in
  `presentation/views/`, a view model in `presentation/view_models/`.
- **A business object** → `domain/entities/`.
- **Data from outside the app** → contract in `domain/repositories/`, adapter in
  `infrastructure/repositories/`, DTO in `infrastructure/dtos/`, endpoint in
  `infrastructure/endpoints/`.
- **Orchestration across repositories, or a rule that isn't screen state** → a
  query and its handler in `domain/usecases/`.
- **Code two or more features need** → `core/`, reachable only from their
  `infrastructure/`. See `core/README.md`.
- **Wiring** → an `@Injectable` annotation on the class itself. Views resolve
  view models, view models resolve the dispatcher, handlers resolve contracts;
  nothing wires by hand.

## Deliberately absent

Each of these lands with its trigger. Adding them earlier is ceremony — and
because git does not track empty directories, an unused folder would not even
survive a clone without a placeholder file:

- `core/networking/`, `core/storage/` — arrive with the first HTTP call and the
  first persisted data.
- `infrastructure/dtos/`, `infrastructure/endpoints/` — arrive with the first
  response that differs from an entity, and the first endpoint.
- `core/design_system/components/` — arrives with the second feature that needs
  the same control. Until then, feature-local widgets live in
  `presentation/widgets/`.
- **App-level bindings live in `lib/provider.dart`**, next to the container rather
  than in a feature's micro-package, and only through an `@ExternalModule`. The
  CQRS dispatcher is the first; a shared HTTP client or a database from `core/`
  joins it when that infrastructure arrives.

## Dependency injection

`injectify` + `get_it`, code-generated. `lib/provider.dart` is the container, and
`main()` awaits `configureDependencies()` before the first frame —
a missing registration surfaces as a build-time throw rather than a silent null.

Registration is folder-scoped. `features/<name>/<name>_module.dart` declares an
`@InjectableMicroPackage`, and every `@Injectable` class under that feature
belongs to it. The root container composes the module but never scans into the
feature, and sibling features cannot see each other's registrations.

Three rules keep DI from dissolving the layering:

- **Adapters bind themselves.** An implementation carries
  `@Injectable(as: <domain contract>)`, so the container names the concrete class
  and no other file does. Nothing outside the feature's module refers to
  `InMemoryProductRepository`.
- **A page reads its view model from the provider.** The router wraps each route
  in a `ChangeNotifierProvider`; the page calls `context.watch<T>()`. A page
  never imports the container, and a test pumps it under
  `ChangeNotifierProvider.value(value: fake, child: page)` — `.value` has no
  dispose callback, so the test keeps ownership of the fake.
- **`watch`, not `read`.** `read` does not subscribe, so a page would never leave
  its loading state. `test/features/shop/presentation/views/` asserts the rebuild.
- **`create:` is a closure, never an inline construction.** Kaisel calls
  `buildPage` on every navigation-driven rebuild (measured: three times for one
  visit), so a view model built at the call site would be rebuilt — and reloaded —
  per call while the mounted page kept the first. Provider guards `create:` with
  its own state, so it runs once per mount. Several view models: `MultiProvider`.
- **Runtime arguments are not injected.** A route argument — a product id — goes
  to `load(id)` rather than into the container. The view model holds no id of its
  own; the `ShopProduct` route stays the only source of it, and the page requires
  it again so its constructor says which product it renders.

Regenerate after adding or changing an annotation — see
[Generated sources](#generated-sources).

## Generated sources

Three generators write Dart into `lib/`, and **none of their output is
committed**:

| Output | Written by | Driven by |
|:-------|:-----------|:----------|
| `*.config.dart` | `injectify_generator` | `build.yaml`, the `@Injectable*` annotations |
| `*.cqrs.dart` | `cqrs_codegen` | the `@CqrsInit` / `@CqrsMicroPackage` annotations |
| `app_theme.g.dart` | `design_builder` | `build.yaml`, `app.tokens.json` |

```bash
dart run build_runner build
```

What follows from ignoring them:

- **A fresh clone does not compile until this has run once**, and CI has to run it
  before `flutter test` or `flutter build`. The imports are real imports; there is
  no fallback and no placeholder to commit.
- **The output is never the thing to edit.** Change the annotated class, the
  annotation, or the token file, then regenerate. `.gitignore` keeps these files
  out of the repo, and `.vscode/settings.json` / `.zed/settings.json` keep them out
  of the file tree and search — both editors can still navigate into them.
- **Output that looks stale is a build that did not run**, not a file to patch. A
  handler or an `@Injectable` that is missing at runtime means the generator has
  not seen it yet.

## CQRS

Reads and writes go through `cqrs`: a handler per use case, a module per
feature, one compositor for the app.

```
lib/
  provider.dart               the container; @CqrsInit composes the feature modules
  provider.cqrs.dart          generated — AppCqrsModule
  features/<name>/
    <name>_handler.dart       @CqrsMicroPackage — the feature's module
    domain/usecases/          query/command + handler, side by side
```

A use case is a message plus a handler. The message names it and carries its
arguments; the handler holds the logic:

```dart
class GetProductsQuery extends Query<List<Product>> {
  const GetProductsQuery();
}

@Injectable(scope: Scope.factory)
class GetProductsQueryHandler
    implements QueryHandler<GetProductsQuery, List<Product>> {
  const GetProductsQueryHandler(this._repository);
  // ...
}
```

A view model never sees a handler. It takes the `CqrsDispatcher` and sends the
message, which is the whole point: the query names the intent and nothing above
it knows what serves it.

```dart
_products = await _dispatcher.query(const GetProductsQuery());
```

The dispatcher is the app's one non-feature container binding — an
`@ExternalModule` in `provider.dart`, beside the container that resolves it:

```dart
CqrsDispatcher()..registry.registerModule(AppCqrsModule.fromLocator(getIt.get))
```

Handlers resolve from the locator **per dispatch**, not when the dispatcher is
built, so a registration that lands later is still reachable and a swapped
adapter is picked up.

Three edges worth knowing before you change this:

- **`generateInjectable: true` is what emits `fromLocator`, and it belongs on
  the feature's `@CqrsMicroPackage` as well as the root `@CqrsInit`.** The root
  emits a call to `ShopCqrsModule.fromLocator` regardless, so a missing flag on
  the feature yields a generated root that does not compile — not a silently
  unwired app. The root alone is not enough; this was verified, not assumed.
- **The default registry is the only registry these modules fit.**
  `HandlerRegistry.resolver(...)` is read-only — its `registerQuery` throws
  `UnsupportedError`. The generated module is the bridge from the container, so
  a resolver-backed registry and the generated modules are mutually exclusive.
- **`cqrs_codegen` is a regular dependency, not a dev one.** The annotations
  (`@CqrsInit`, `@CqrsMicroPackage`) live in the generator package and `lib/`
  imports them; as a dev dependency the `depend_on_referenced_packages` lint
  fires on every annotated file.

Regenerate after adding a handler — the module will not register one it has not
seen:

```bash
dart run build_runner build
```

## Pinned dependencies

`cqrs` and `cqrs_codegen` come from a git monorepo, pinned to a commit because
the repository publishes no tags. Two consequences worth knowing:

- **The `dependency_overrides` block in `pubspec.yaml` is load-bearing.**
  `cqrs_codegen` declares its sibling `cqrs` as a *hosted* dependency, and pub
  refuses to unify that with a git source. Without the override, resolution
  fails; with it, both packages come from one checkout. It also keeps the
  generator off the unrelated `cqrs` package that already owns that name on
  pub.dev.
- **Bumping means editing the `ref` in all three blocks** — `cqrs`,
  `cqrs_codegen`, and the override — then `flutter pub get`. `pubspec.lock` pins
  the resolved commit for everyone else.

## Design system

No widget hardcodes a visual value. Tokens — colors, sizes, typography — live in
`core/design_system/app.tokens.json` and `design_builder` compiles them into
`app_theme.g.dart` at build time. See `core/README.md` for the edit → regenerate
flow.

`lib/app/app.dart` owns the `AppThemeNotifier` and wraps `MaterialApp` in
`AppThemeProvider.builder`, so toggling the mode rebuilds the app with the other
token set. Screens read tokens with `context.theme.colors/sizes/typography`.

Two things that look like cleanups and are not:

- **Moving the theme notifier into the container.** It is widget-tree state: a
  mode change has to rebuild `MaterialApp`, and `get_it` cannot rebuild
  anything. It is the one app-level binding that stays out of DI.
- **Editing `app_theme.g.dart`.** It is regenerated wholesale. A value that is
  wrong is wrong in the JSON — unless it is missing from the generated output
  entirely, which means the token's `$type` or its group is absent from
  `theme-spec.schema.json`, and the builder skipped it without a warning.

## Invariants the tests enforce

`test/architecture_test.dart` reads every import and fails when `core/`,
`features/*/domain/`, or `features/*/presentation/` break the Rules table above.
Two of those are load-bearing: a view never imports `infrastructure/`, and a
view *or view model* never imports `domain/repositories/`. Together they are what
keeps data access below the UI. Do not weaken the test to make a change pass.
(`infrastructure/` itself is unconstrained on purpose.)

Also enforced, elsewhere:

- **One adapter is named, once.** Tests mock the *domain contract*
  (`test/features/shop/domain/repositories/mock_product_repository.dart`), never
  the adapter. Swapping `InMemoryProductRepository` for a real one must not touch
  a single test.
- **The feature stays `const`.** See the shared-container note above.
- **Provider owns the view model**: `ChangeNotifierProvider` creates it once per
  mount and disposes it on unmount. Factory scope means the container will not
  dispose it, and kaisel's repeated `buildPage` calls mean it must not be created
  at the call site.
- **URLs round-trip.** `test/app_codec_test.dart` covers encode/decode for every
  mount.

## Failure modes

Things that look like improvements and are not:

- **Splitting out a separate `application/` layer for use cases.** That is the
  .NET/Java four-layer arrangement; this project follows the iOS reference, where
  use cases live in `domain/usecases/`. CQRS does not move that line: a query and
  its handler are the use case, and both stay in Domain.
- **Renaming `features/` to `modules/`, or `views/` to `pages/`.** Kaisel calls
  its mountable unit a module and its builder `buildPage` — that is library
  vocabulary, not folder vocabulary. The folders follow the iOS reference.
- **Letting a view or view model reach for a concrete repository.** The
  dependency inversion is what makes the adapter swappable in one line.
- **Adding a screen or a route to `lib/app/` instead of a feature.** `app/` is
  routing and composition only: three mount markers and no screens. The landing
  screen lives in `features/home/` for exactly that reason.
- **Putting shared code in one feature** because `core/` "feels empty". The
  second consumer is the trigger, not the first.
- **Letting `core/` import a feature.** That inverts the foundation and the
  architecture test will catch it.
- **Giving a view model a repository.** It takes the dispatcher and sends a
  query. A view model that imports `domain/repositories/` fails the architecture
  test.
- **Giving a view model a handler.** Same reason as the dispatcher: the message
  is the seam. Injecting the handler re-couples the caller to the
  implementation, and the query type stops being the contract.
- **Calling `load()` from a page's `initState`.** The read triggers the
  provider's lazy `create` and attaches its listener, so the view model's first
  `notifyListeners()` marks the provider dirty mid-mount and trips
  `'!_dirty': is not true`. Load inside `create:` — provider attaches its
  listener only after `create` returns.
- **`context.read` in a page's build.** It does not subscribe, so the page stops
  rebuilding — a list would sit on its spinner forever. `watch` is the one that
  keeps it live.
- **Rendering a page with no provider above it.** The page resolves its view
  model from the environment now, not from its constructor, so a bare
  `pumpWidget(ShopHomeView())` throws `ProviderNotFoundException`. Wrap it, as
  `test/features/shop/presentation/views/view_host.dart` does — that wrapper is
  the cost of this shape.
- **Registering a view model as a singleton.** It would be shared across mounts
  and outlive the page that owns it. `Scope.factory` plus `ChangeNotifierProvider`
  disposal is the rule — the container does not dispose factories.
- **Constructing a view model where `buildPage` returns.** It looks like the
  natural wiring point and it is not: that method runs once per navigation
  rebuild, so the page reloads and the extra instances go undisposed. Hand
  `create:` a closure inside a provider instead.
