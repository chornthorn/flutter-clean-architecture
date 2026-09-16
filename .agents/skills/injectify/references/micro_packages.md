# Micro-Packages & Monorepo Architecture

**Micro-Packages** allow large Dart and Flutter codebases to partition their dependency graph into small, self-contained, modular units.

---

## 1. Folder-Scoped Micro-Packages

In a single-package project or feature-rich app, you can isolate folders into their own micro-package modules without creating separate `pubspec.yaml` files.

### Project Layout

```
lib/
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   └── auth_repository.dart    # @Injectable(scope: Scope.lazySingleton)
│   │   ├── domain/
│   │   │   └── login_usecase.dart      # @Injectable(scope: Scope.factory)
│   │   └── auth_module.dart            # @InjectableMicroPackage(moduleName: 'Auth')
│   │
│   └── catalog/
│       ├── catalog_service.dart        # @Injectable(scope: Scope.lazySingleton)
│       └── catalog_module.dart         # @InjectableMicroPackage(moduleName: 'Catalog')
│
└── injection.dart                      # @InjectableInit(useMicroPackage: true)
```

### Module Definition

In `lib/features/auth/auth_module.dart`:

```dart
import 'package:injectify/injectify.dart';

@InjectableMicroPackage(moduleName: 'Auth')
void configureAuthModule() {}
```

This generates `auth_module.config.dart` containing `AuthInjectableModule extends MicroPackageModule`.

### Scoping & Boundary Isolation Rules

1. **Strict Folder Boundaries**: Any class annotated with `@Injectable()` located within `lib/features/auth/` and its subdirectories is assigned exclusively to `AuthInjectableModule`.
2. **Exclusion from Sibling Modules**: The root generator and sibling micro-packages ignore these files during their scanning phases.
3. **Auto-Discovery at Root**: When the root `lib/injection.dart` has `@InjectableInit(useMicroPackage: true)`, the root generator automatically discovers all folder micro-packages and emits `gh.initMicroPackage(AuthInjectableModule())`.

---

## 2. Nested Micro-Packages

Micro-packages can be nested hierarchically. A parent micro-package can auto-compose child micro-packages inside its subfolders.

```
lib/features/catalog/
├── catalog_module.dart                 # @InjectableMicroPackage(moduleName: 'Catalog', useMicroPackage: true)
├── catalog_service.dart                # Belongs to Catalog module
└── reviews/
    ├── reviews_module.dart             # @InjectableMicroPackage(moduleName: 'Reviews')
    └── reviews_repository.dart         # Belongs to Reviews module
```

### Parent Module Configuration

```dart
// lib/features/catalog/catalog_module.dart
import 'package:injectify/injectify.dart';

@InjectableMicroPackage(
  moduleName: 'Catalog',
  useMicroPackage: true, // Automatically composes ReviewsInjectableModule inside Catalog
)
void configureCatalogModule() {}
```

> [!CAUTION]
> **Single Composition Rule**:
> Compose each module exactly once. If `CatalogInjectableModule` composes `ReviewsInjectableModule` with `useMicroPackage: true`, the root container must NOT compose `ReviewsInjectableModule` again, preventing GetIt duplicate registration errors.

---

## 3. Multi-Package Monorepo Composition

When features live in separate packages with their own `pubspec.yaml` (e.g. `packages/shared`, `packages/feature_auth`), use `externalMicroPackages`.

### Monorepo Structure

```
my_monorepo/
├── packages/
│   └── core_network/
│       ├── pubspec.yaml
│       └── lib/
│           ├── network_client.dart
│           └── core_network_module.dart   # @InjectableInit.microPackage(moduleName: 'CoreNetwork')
│
└── apps/
    └── main_app/
        ├── pubspec.yaml                   # depends on core_network
        └── lib/
            └── injection.dart             # @InjectableInit(externalMicroPackages: [...])
```

### External Package Definition

In `packages/core_network/lib/core_network_module.dart`:

```dart
import 'package:injectify/injectify.dart';

@InjectableInit.microPackage(moduleName: 'CoreNetwork')
void configureCoreNetwork() {}
```

Run `dart run build_runner build` inside `packages/core_network` to generate `core_network_module.config.dart` containing `CoreNetworkInjectableModule`.

### Composing in the Root App

In `apps/main_app/lib/injection.dart`:

```dart
import 'package:core_network/core_network_module.config.dart';
import 'package:get_it/get_it.dart';
import 'package:injectify/injectify.dart';

import 'injection.config.dart';

final getIt = GetIt.instance;

@InjectableInit(
  preferRelativeImports: true,
  asExtension: true,
  useMicroPackage: true,
  externalMicroPackages: [
    ExternalMicroPackage(CoreNetworkInjectableModule),
  ],
)
Future<void> configureDependencies({String? environment}) async =>
    getIt.init(environment: environment);
```

### Emitted Root Initialization Code

```dart
extension GetItInjectableX on GetIt {
  Future<GetIt> init({String? environment, EnvironmentFilter? environmentFilter}) async {
    final gh = GetItHelper(
      this,
      environment: environment,
      environmentFilter: environmentFilter,
    );
    gh.initMicroPackage(CoreNetworkInjectableModule());
    // registers local micro-packages and app dependencies...
    return this;
  }
}
```
