# Kaisel Generator (`kaisel_generator`)

Blazing-fast, Rust-based Dart code generator and annotation toolkit for [Kaisel](https://pub.dev/packages/kaisel) module mounting and route registry, communicating via **Dart FFI** directly into compiled native Rust.

Generates the host's sealed `AppRoute` hierarchy, `buildAppModulePage`, `ConfigCodecWithModules`, and `defaultAppRouterConfig` in **under 10 milliseconds**, bypassing the slow semantic type analysis of Dart's `build_runner`.

---

## Architecture: In-Process Dart FFI

Unlike traditional code generators that either run in an external subprocess or suffer from slow Dart VM semantic analyzers:

- **Zero Process Overhead**: Dart binds directly to `libkaisel_generator` via `dart:ffi`.
- **Ultra-Low Latency**: In-process C-ABI function calls execute and return in ~5-15 ms.
- **Micro-Package Native**: Micro-packages declare their mounts as typed values; hosts compose them and generate in-project manifests.
- **Unified Package**: Contains Dart annotations (`@KaiselModule`, `@KaiselMicroPackage`, `@KaiselInit`), Dart CLI runner (`bin/kaisel_generator.dart`), Dart FFI bindings (`KaiselBindings`, `KaiselGenerator`), and native Rust engine (`src/`).

---

## Installation

Add `kaisel_generator` to your `pubspec.yaml`. Generated code imports
`package:kaisel_generator/micro_mount.dart` — a separate entrypoint so that app
builds pull neither the ffi bindings nor the CLI's dependencies:

```yaml
dependencies:
  kaisel: ^1.1.0
  kaisel_generator:
    path: packages/kaisel_generator # or hosted git/pub.dev
```

---

## Quick Start Guide

### 1. Initialize Configuration

You can configure the generator either using `kaisel.yaml` or the `@KaiselInit()` annotation.

#### Option A: `kaisel.yaml` (Recommended)

Place a `kaisel.yaml` file in the root of your Flutter project:

```yaml
# kaisel.yaml
output: lib/app/app_modules.g.dart
lib_dir: lib
route_class: AppRoute
```

#### Option B: `@KaiselInit` Annotation (Similar to `@InjectableInit` / `@CqrsInit`)

Decouple route configuration completely from your UI/Widget tree by annotating a top-level function or configuration entry point (e.g. in `lib/app/app.dart`):

```dart
import 'package:flutter/material.dart';
import 'package:kaisel/kaisel.dart';
import 'package:kaisel_generator/kaisel_generator.dart';

import 'app_modules.g.dart';

export 'app_modules.g.dart';

// Decoupled routing entry point
@KaiselInit()
void configureRouting() {}

// The app's router, configured from the generated module registry.
final appRouterConfig = defaultAppRouterConfig;

// Your Widget tree stays 100% standard Flutter and decoupled from annotations
class KaiselApp extends StatelessWidget {
  const KaiselApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: appRouterConfig,
    );
  }
}
```

---

### 2. Micro-Package Support

A micro-package is an independent Dart package that declares its mounts and is composed by a host
application. In a monorepo with `packages/feature_shop` and `packages/feature_posts`:

1. Register the package in the host app (step 2). If the package is not part of the host's project, generate its manifest there as well — `cd packages/feature_shop && dart run kaisel_generator` — since a host outside the project cannot write it:

   ```dart
   // packages/feature_shop/lib/feature_shop.dart
   @KaiselMicroPackage(moduleName: 'FeatureShop', prefix: '/shop')
   void configureShop() {}
   ```

   This generates `lib/feature_shop.kaisel.dart` with `FeatureShopKaiselModule`, which declares each mount it contributes as a typed `KaiselMicroMount` — its module, prefix, codec and whether the host should land on it. There are no mount names in the contract for a host to dispatch on.

2. In the root app, compose the generated modules via `externalMicroPackages`:

   ```dart
   // app/lib/app/app.dart
   import 'package:kaisel_generator/kaisel_generator.dart';

   @KaiselInit(
     externalMicroPackages: [
       // Resolved to package:feature_shop/feature_shop.kaisel.dart.
       ExternalMicroPackage(FeatureShopKaiselModule),
       // Explicit import for custom package or manifest names.
       ExternalMicroPackage(
         FeaturePostsKaiselModule,
         import: 'package:feature_posts/src/posts.kaisel.dart',
       ),
     ],
   )
   void configureRouting() {}
   ```

   The host declares a marker route per mount the package declares, and binds each
   one to its own typed route by passing the marker _instance_:

   ```dart
   // app/lib/app/app_modules.g.dart
   final class ShopMount extends AppRoute {
     const ShopMount();
   }

   Widget buildAppModulePage(BuildContext context, AppRoute route) => switch (route) {
     // ...host modules
     ShopMount() => _mp1.FeatureShopKaiselModule.shopMount.page,
   };

   final appModuleMounts = <ModuleMount<AppRoute>>[
     // ...host modules
     _mp1.FeatureShopKaiselModule.shopMount.moduleMount(const ShopMount()),
   ];

   Uri? encodeAppModuleRoute(AppRoute route) => switch (route) {
     // ...host modules
     ShopMount() => _mp1.FeatureShopKaiselModule.shopMount.url,
   };
   ```

   Pages, URL prefixes and codecs come from the package's declaration, so the host
   keeps no second copy of them; the manifest is imported as `_mp1`, `_mp2`, ... —
   the same way feature modules are aliased as `_i1`, `_i2`, ...

   Because the binding is a value, a mount that is renamed or dropped in the package
   fails to compile instead of silently falling back to another route.

Resolution notes:

- `ExternalMicroPackage(FeatureShopKaiselModule)` infers
  `package:feature_shop/feature_shop.kaisel.dart`. Pass `import:` when the package name
  or manifest file differs from that convention.
- `package:` imports are resolved through the host's `.dart_tool/package_config.json`,
  so run `dart pub get` in the host app and generate the micro-package first.
- External packages are composed from their manifest. A package that lives inside the host's own project is generated by the host's run, so registering it is the only step the app writes; a package outside the project must generate its own manifest, and a missing one fails generation with that instruction. A mount that would land on a name the host already uses gets its owner inserted — the package's `ShopMount` next to the host's `ShopMount` is bound to `ShopProfileMount`, so a package never forces a hand-picked name.

---

### 3. Annotate Feature Modules

Annotate your `RouteModule` classes with `@KaiselModule`:

```dart
import 'package:kaisel/kaisel.dart';
import 'package:kaisel_generator/kaisel_generator.dart';

// Mark as the initial landing module
@KaiselModule(isInitial: true)
class HomeRouterModule extends RouteModule<HomeRoute> {
  const HomeRouterModule();
  // ...
}

// Mount with a URL prefix and route codec
@KaiselModule(prefix: '/shop', codec: ShopRouteCodec)
class ShopRouterModule extends RouteModule<ShopRoute> {
  const ShopRouterModule();
  // ...
}

@KaiselModule(prefix: '/posts')
class PostsRouterModule extends RouteModule<PostsRoute> {
  const PostsRouterModule();
  // ...
}
```

#### `@KaiselModule` Options

| Parameter   | Type      | Description                                                                                                      |
| :---------- | :-------- | :--------------------------------------------------------------------------------------------------------------- |
| `prefix`    | `String?` | URL prefix for deep linking (e.g. `'/shop'`). If omitted, the module is not URL-routed.                          |
| `mount`     | `String?` | Custom name for the generated marker class (e.g. `'ShopMount'`). Defaults to `<Feature>Mount`.                   |
| `isInitial` | `bool`    | Marks this module as the default entry point (`kInitialAppRoute`). Default: `false`.                             |
| `codec`     | `Type?`   | Explicit `KaiselConfigCodec` type. If omitted, the generator automatically inspects the module's `codec` getter. |

---

### 4. Run the Generator

#### Inside `build_runner` (recommended)

Enable the builder in the host app:

```yaml
# build.yaml
targets:
  $default:
    builders:
      kaisel_generator|kaisel:
        enabled: true
```

```bash
dart run build_runner build
```

The builder runs once per package for anything under `lib/` (the `$lib$` input, so
the host's `@KaiselInit` file can live anywhere) and produces the registry through
`build_runner`, which therefore _owns_ that file: it rewrites it when inputs
change, drops it when conflicting, and skips the builder when nothing changed.

What each side owns:

| File                                   | Written by                      | Why                                                                                                             |
| :------------------------------------- | :------------------------------ | :-------------------------------------------------------------------------------------------------------------- |
| `lib/app/app_modules.g.dart`           | the builder, via `build_runner` | declared output; build_runner tracks and manages it                                                             |
| `features/<pkg>/lib/<pkg>.kaisel.dart` | the engine                      | another package's asset — build_runner forbids a builder writing it, yet the registry cannot compile without it |

Notes:

- The declared output must match `kaisel.yaml: output`. For a different path, declare your
  own builder in the app's `build.yaml` (`import: package:kaisel_generator/builder.dart`,
  `builder_factories: [kaiselBuilder]`, `build_extensions: {"$lib$": ["<path relative to lib/>"]}`,
  `build_to: source`) — the builder tells you exactly that if the two disagree.
- **Engine revision:** the engine cannot be an asset of your package, so build_runner cannot
  see it change. Bump `ENGINE_REVISION` in `src/config.rs` and `_engineRevision` in
  `lib/builder.dart` together: the Dart bump invalidates the builder, and a mismatch between
  the two fails the build instead of silently using an older engine.
- `dart run kaisel_generator --clean` removes the registry and every manifest;
  `build_runner clean` clears its cache but leaves `build_to: source` outputs behind.

#### Via Dart CLI (Uses Dart FFI)

```bash
# Standard workflow via Dart FFI (no build_runner: standalone packages, watch mode,
# or a host that has not enabled the builder)
dart run kaisel_generator

# Watch mode (monitors lib/ and re-generates via FFI)
dart run kaisel_generator --watch

# Force full regeneration ignoring cache
dart run kaisel_generator --force

# Remove the generated registry and every *.kaisel.dart manifest
dart run kaisel_generator --clean
```

#### Programmatically in Dart

```dart
import 'package:kaisel_generator/kaisel_generator.dart';

void main() async {
  final result = await KaiselGenerator.generate(
    root: '.',
    force: false,
  );
  print('Generated ${result.modulesCount} mounts in ${result.elapsedDisplay}');
}
```

---

### 5. Performance Fixture

`tool/perf_monorepo.dart` writes a throwaway monorepo into `.temp/perf` (git-ignored) and times
the generator on it: a host app with `--host-modules` modules, one `@KaiselMicroPackage` per
`--packages`, and `--routes` routes in every module.

```bash
cd packages/kaisel_generator
dart run tool/perf_monorepo.dart                       # 25 packages × 10 routes × 3 runs
dart run tool/perf_monorepo.dart --packages 100 --routes 12 --runs 5
dart run tool/perf_monorepo.dart --analyze             # also type-checks the output
dart run tool/perf_monorepo.dart --clean
```

It fails (exit 1) if a run errors or if the registry does not hold one mount per module, so it
doubles as a scale smoke test. `--analyze` runs `flutter pub get` + `flutter analyze` inside the
fixture, which type-checks every generated manifest and the registry.

---

### 6. What Gets Generated

The generator creates `lib/app/app_modules.g.dart` (and `*.kaisel.dart` for micro-packages) with:

- **Sealed `AppRoute` hierarchy**: `HomeMount`, `ShopMount`, `PostsMount`, `SettingsMount` — including mounts contributed by external micro-packages.
- **`buildAppModulePage`**: Matches routes to `KaiselModuleMount` using aliased module imports (`_i1`, `_i2`, ...) and delegates micro-package mounts to their typed declarations (`_mp1`, `_mp2`, ...) to guarantee zero symbol collisions.
- **`appModuleMounts`**: Declarative `ModuleMount` list for URL routing, binding each micro-package declaration to the host marker instance it belongs to.
- **`defaultAppCodec`**: Complete composite URL codec.
- **`defaultAppRouterConfig` & `createAppRouterConfig(...)`**: Ready-to-use `KaiselRouterConfig<AppRoute>`.

Micro-package manifests (`*.kaisel.dart`) expose one `KaiselMicroMount` declaration per
mount they contribute, e.g.:

```dart
abstract final class ProfileKaiselModule {
  /// The mount this package contributes for `ProfileMount`.
  static const KaiselMicroMount<ProfileRoute> profileMount =
      KaiselMicroMount<ProfileRoute>(
    prefix: '/profile',
    module: ProfileRouterModule(),
    codec: ProfileRouteCodec(),
  );
}
```

The mount name a host uses is derived from the field name (`profileMount` →
`ProfileMount`), so no route is ever looked up by string at runtime.
