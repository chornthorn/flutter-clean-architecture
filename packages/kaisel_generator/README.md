# Kaisel Generator (`kaisel_generator`)

Blazing-fast, Rust-based Dart code generator and annotation toolkit for [Kaisel](https://pub.dev/packages/kaisel) module mounting and route registry, communicating via **Dart FFI** directly into compiled native Rust.

Generates the host's sealed `AppRoute` hierarchy, `buildAppModulePage`, `ConfigCodecWithModules`, and `defaultAppRouterConfig` in **under 10 milliseconds**, bypassing the slow semantic type analysis of Dart's `build_runner`.

---

## Architecture: In-Process Dart FFI

Unlike traditional code generators that either run in an external subprocess or suffer from slow Dart VM semantic analyzers:

- **Zero Process Overhead**: Dart binds directly to `libkaisel_generator` via `dart:ffi`.
- **Ultra-Low Latency**: In-process C-ABI function calls execute and return in ~5 ms.
- **Unified Package**: Contains both Dart annotations (`@KaiselModule`, `@KaiselInit`), Dart CLI runner (`bin/kaisel_generator.dart`), Dart FFI bindings (`KaiselBindings`, `KaiselGenerator`), and native Rust engine (`src/`).

---

## Installation

Add `kaisel_generator` to your `pubspec.yaml`:

```yaml
dependencies:
  kaisel: ^1.1.0
  kaisel_generator:
    path: packages/kaisel_generator # or hosted git/pub.dev
```

---

## Quick Start Guide

### 1. Initialize Configuration

You can configure the generator either using a configuration file or a Dart annotation.

#### Option A: `kaisel.yaml` (Recommended)

Place a `kaisel.yaml` file in the root of your Flutter project:

```yaml
# kaisel.yaml
output: lib/app/app_modules.g.dart
lib_dir: lib
route_class: AppRoute
```

#### Option B: `@KaiselInit` Annotation

In your app's entry file (e.g. `lib/app/app.dart`):

```dart
import 'package:flutter/material.dart';
import 'package:kaisel/kaisel.dart';
import 'package:kaisel_generator/kaisel_generator.dart';

import 'app_modules.g.dart';

export 'app_modules.g.dart';

final appRouterConfig = defaultAppRouterConfig;

@KaiselInit()
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

### 2. Annotate Feature Modules

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

### 3. Run the Generator

#### Via Dart CLI (Uses Dart FFI)

```bash
# Standard workflow via Dart FFI
dart run kaisel_generator

# Watch mode (monitors lib/ and re-generates via FFI)
dart run kaisel_generator --watch

# Force full regeneration ignoring cache
dart run kaisel_generator --force
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

#### Via Cargo (Standalone Native CLI)

```bash
cargo run --release --manifest-path packages/kaisel_generator/Cargo.toml
```

---

### 4. What Gets Generated

The generator creates `lib/app/app_modules.g.dart` with:

- **Sealed `AppRoute` family**: `HomeMount`, `ShopMount`, `PostsMount`, `SettingsMount`.
- **`buildAppModulePage`**: Matches routes to `KaiselModuleMount` using aliased module imports (`_i1`, `_i2`, ...) to guarantee zero symbol collisions.
- **`appModuleMounts`**: Declarative `ModuleMount` list for URL routing.
- **`defaultAppCodec` & `appCodec`**: Complete composite URL codec.
- **`defaultAppRouterConfig` & `createAppRouterConfig(...)`**: Ready-to-use `KaiselRouterConfig<AppRoute>`.
