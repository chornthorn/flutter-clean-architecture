---
name: injectify
description: Complete dependency injection toolkit for Dart & Flutter using Injectify and GetIt with code generation, folder-scoped micro-packages, third-party modules, and asynchronous startup. Use when setting up or modifying dependency injection, annotating classes with @Injectable, configuring @InjectableInit or @InjectableMicroPackage, wiring third-party providers with @ExternalModule, managing lifetimes (factory, lazySingleton, singleton), or generating DI code with build_runner in Dart/Flutter projects.
license: Apache-2.0
metadata:
  author: injectify-dart
  version: "1.0.0"
---

# Injectify Dependency Injection Skill

This skill provides step-by-step instructions, architectural patterns, and code generation rules for building robust, scalable Dependency Injection in Dart and Flutter projects using **Injectify** and **GetIt**.

---

## When to Use This Skill

Activate this skill whenever you need to:

- Set up or configure Dependency Injection in a Dart or Flutter app.
- Annotate services, repositories, view models, or BLoCs/Cubits with `@Injectable()`.
- Configure root container initialization with `@InjectableInit()`.
- Structure modular architectures with folder-scoped `@InjectableMicroPackage()`.
- Wire external / third-party classes (e.g., `Dio`, `SharedPreferences`, `FirebaseAuth`) using `@ExternalModule()`.
- Compose cross-package micro-modules in monorepos via `externalMicroPackages`.
- Handle asynchronous initialization and `@PreResolve()`.
- Run and troubleshoot code generation (`build_runner`).

---

## Core Rules & Modern Syntax Conventions

> [!IMPORTANT]
> **No Deprecated Syntax / Strict Modern API**:
>
> - **Class-form annotations only**: Use `@Injectable()`, `@InjectableInit()`, `@InjectableMicroPackage()`, `@ExternalModule()`, `@FactoryParam()`. Do not use legacy const-variable annotations (`@injectable`, `@module`, `@singleton`).
> - **Scopes use explicit enum**: `@Injectable(scope: Scope.lazySingleton)`, `@Injectable(scope: Scope.singleton)`, or `@Injectable(scope: Scope.factory)` (default).
> - **Qualifiers**: Use `@Inject('tag')` for named lookups (not `@Named`).
> - **Third-party modules**: Use `@ExternalModule()` (not `@module` or `@thirdParty`).
> - **Clean and breaking changes**: Always write modern, type-safe annotations without legacy fallbacks.

---

## Quickstart Workflow

### 1. Configure Dependencies (`pubspec.yaml`)

```yaml
dependencies:
  get_it: ^9.2.1
  injectify: ^0.1.0

dev_dependencies:
  build_runner: ^2.4.0
  injectify_generator: ^0.1.0
```

### 2. Set Up Root Container (`lib/injection.dart`)

Create `lib/injection.dart` with `@InjectableInit()`:

```dart
import 'package:get_it/get_it.dart';
import 'package:injectify/injectify.dart';

import 'injection.config.dart';

final getIt = GetIt.instance;

@InjectableInit(
  initializerName: 'init',
  preferRelativeImports: true,
  asExtension: true,
  useMicroPackage: true, // Enables auto-discovery of folder micro-packages
)
Future<void> configureDependencies({String? environment}) async =>
    getIt.init(environment: environment);
```

### 3. Define Injectable Services

```dart
import 'package:injectify/injectify.dart';

// 1. Factory (new instance on each lookup - default)
@Injectable(scope: Scope.factory)
class UserRepository {
  final ApiService apiService;
  UserRepository(this.apiService);
}

// 2. Lazy Singleton (instantiated on first lookup)
@Injectable(scope: Scope.lazySingleton)
class ApiService {
  final String baseUrl;
  ApiService({this.baseUrl = 'https://api.example.com'});
}

// 3. Eager Singleton (instantiated during container init)
@Injectable(scope: Scope.singleton)
class AppConfig {
  final String appName = 'My App';
}

// 4. Interface Binding
abstract class AuthService {}

@Injectable(as: AuthService, scope: Scope.lazySingleton)
class AuthServiceImpl implements AuthService {}
```

### 4. Run Code Generation

Execute the build runner command to produce `.config.dart`:

```bash
# Dart and Flutter projects (Flutter bundles the Dart SDK)
dart run build_runner build --delete-conflicting-outputs
```

### 5. Initialize Container at App Entry (`main.dart`)

```dart
import 'package:flutter/material.dart';
import 'injection.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const MyApp());
}
```

---

## Architecture Reference & Deep Dives

For detailed patterns and implementation guides, consult the reference documents:

- **[Annotations & Lifecycles](references/annotations.md)**: Exhaustive reference of all annotations (`@Injectable`, `@InjectableInit`, `@ExternalModule`, `@Inject`, `@FactoryParam`, `@PreResolve`, `@Order`, `@DisposeMethod`).
- **[Micro-Packages & Monorepos](references/micro_packages.md)**: Folder-scoped boundaries (`@InjectableMicroPackage`), nested sub-modules, and multi-pubspec external module composition (`externalMicroPackages`).
- **[Common Recipes](references/recipes.md)**: Third-party client wiring (Dio, SharedPreferences, Hive), BLoC/Cubit injection, parameterized runtime factories, and environment-based testing/mocking.
- **[Troubleshooting & Diagnostics](references/troubleshooting.md)**: Resolving circular dependencies, missing awaits, unindexed types, and build runner cache issues.

---

## Standard Templates

Starter templates are available in the [assets/](assets/) directory:

- [assets/injection_template.dart](assets/injection_template.dart): Standard root container initializer.
- [assets/module_template.dart](assets/module_template.dart): Folder-scoped micro-package template.
- [assets/build.yaml](assets/build.yaml): Recommended `build.yaml` options for code generation.
