# Injectify Annotations & Lifecycle Reference

Complete API specification and usage guide for all annotations supported by `injectify`.

---

## 1. `@Injectable()`

Marks a class as a dependency eligible for service locator registration.

### Parameters

| Field          | Type            | Default         | Description                                                                                   |
| :------------- | :-------------- | :-------------- | :-------------------------------------------------------------------------------------------- |
| `scope`        | `Scope`         | `Scope.factory` | Lifetime: `Scope.factory`, `Scope.lazySingleton`, or `Scope.singleton`.                       |
| `as`           | `Type?`         | `null`          | Abstract type / interface to bind the implementation to.                                      |
| `env`          | `List<String>?` | `null`          | Active environments (e.g. `['dev', 'test']`).                                                 |
| `order`        | `int?`          | `null`          | Priority registration index (lower runs earlier).                                             |
| `getItScope`   | `String?`       | `null`          | Accepted by the annotation API but not yet emitted by the generator (reserved).               |
| `signalsReady` | `bool?`         | `null`          | Whether GetIt waits for this singleton to signal ready.                                       |
| `dependsOn`    | `List<Type>?`   | `null`          | Accepted by the annotation API but not yet emitted by the generator (reserved).               |
| `dispose`      | `Function?`     | `null`          | Optional dispose callback field. Disposal is wired from methods marked with `@DisposeMethod`. |

### Lifecycle Scopes

```dart
// Factory: New instance every lookup
@Injectable(scope: Scope.factory)
class OrderViewModel {}

// Lazy Singleton: Single shared instance, constructed on first getIt<T>()
@Injectable(scope: Scope.lazySingleton)
class AuthService {}

// Eager Singleton: Constructed immediately during getIt.init()
@Injectable(scope: Scope.singleton)
class DatabaseClient {}
```

### Interface Binding

```dart
abstract class StorageService {
  Future<void> save(String key, String value);
}

@Injectable(as: StorageService, scope: Scope.lazySingleton)
class SecureStorageService implements StorageService {
  @override
  Future<void> save(String key, String value) async {}
}
```

---

## 2. `@InjectableInit()`

Marks the root entrypoint function that configures dependency injection for the entire application or root module.

```dart
@InjectableInit(
  initializerName: 'init',
  preferRelativeImports: true,
  asExtension: true,
  useMicroPackage: true,
  externalMicroPackages: [
    ExternalMicroPackage(SharedInjectableModule),
  ],
)
Future<void> configureDependencies({String? environment}) async =>
    getIt.init(environment: environment);
```

### Parameters

- `initializerName` (`String`, default `'init'`): Name of the generated extension method on `GetIt`.
- `preferRelativeImports` (`bool`, default `true`): Uses relative import paths within the same package.
- `asExtension` (`bool`, default `true`): Generates an extension on `GetIt` (e.g., `getIt.init()`).
- `generateForDir` (`List<String>`, default `['lib']`): Directories to scan for injectable classes.
- `useMicroPackage` (`bool`, default `false`): Enables auto-discovery and flat registration of all folder-scoped `@InjectableMicroPackage` modules.
- `modules` (`List<Type>`, default `[]`): Explicit list of locally-discovered module classes to compose.
- `externalMicroPackages` (`List<ExternalMicroPackage>`, default `[]`): List of micro-package modules from external pubspec packages in a monorepo.
- `allowMultipleRegistrations` (`bool?`): When true, permits duplicate registrations without throwing.

---

## 3. `@InjectableMicroPackage()`

Defines an isolated, folder-scoped micro-package module.

```dart
@InjectableMicroPackage(
  moduleName: 'Auth',
  useMicroPackage: false,
)
void configureAuthModule() {}
```

- When placed in a directory (e.g. `lib/features/auth/auth_module.dart`), all dependencies in that directory and its subdirectories belong exclusively to the `AuthInjectableModule`.
- Sub-modules can set `useMicroPackage: true` to auto-compose nested sub-folder micro-packages.

---

## 4. `@ExternalModule()`

Marks an abstract class as a provider for third-party or externally constructed instances (e.g. `Dio`, `SharedPreferences`, `PackageInfo`).

```dart
import 'package:dio/dio.dart';
import 'package:injectify/injectify.dart';
import 'package:shared_preferences/shared_preferences.dart';

@ExternalModule()
abstract class ThirdPartyModule {
  @Injectable(scope: Scope.lazySingleton)
  Dio dio() => Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));

  @PreResolve()
  @Injectable(scope: Scope.singleton)
  Future<SharedPreferences> get prefs => SharedPreferences.getInstance();
}
```

---

## 5. `@Inject('tag')`

Qualifies a parameter or dependency with an explicit string identifier when multiple implementations of the same type exist.

```dart
@ExternalModule()
abstract class NetworkModule {
  @Injectable(scope: Scope.lazySingleton)
  @Inject('authDio')
  Dio authDio() => Dio(BaseOptions(baseUrl: 'https://auth.example.com'));

  @Injectable(scope: Scope.lazySingleton)
  @Inject('apiDio')
  Dio apiDio() => Dio(BaseOptions(baseUrl: 'https://api.example.com'));
}

@Injectable(scope: Scope.factory)
class PaymentService {
  final Dio client;
  PaymentService(@Inject('apiDio') this.client);
}
```

---

## 6. `@FactoryParam()`

Marks dynamic runtime parameters passed when resolving a factory from `getIt.get<T>(param1: ..., param2: ...)`. Supports up to 2 factory parameters (GetIt limitation).

```dart
@Injectable(scope: Scope.factory)
class UserProfileBloc {
  final ApiService api;
  final String userId;

  UserProfileBloc(
    this.api, {
    @FactoryParam() required this.userId,
  });
}

// Resolution in UI code:
final bloc = getIt<UserProfileBloc>(param1: 'user_123');
```

---

## 7. `@PreResolve()`

Marks a class (or external module member) as an asynchronous singleton. The generator emits `await gh.singletonAsync<T>(...)`, registering the instance as **pending**. The future completes when the app calls `await getIt.allReady()` or `await getIt.getAsync<T>()` — before that, synchronous `getIt<T>()` throws.

```dart
@PreResolve()
@Injectable(scope: Scope.singleton)
class DatabaseService {
  final Future<void> opened;

  DatabaseService() : opened = _open();

  static Future<void> _open() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }
}
```

Generated registration:

```dart
await gh.singletonAsync<DatabaseService>(() async => DatabaseService());
```

---

## 8. `@Environment('name')`

Conditionally registers dependencies based on the active runtime environment.

```dart
@Environment(Environment.dev)
@Injectable(as: ApiClient, scope: Scope.lazySingleton)
class MockApiClient implements ApiClient {}

@Environment(Environment.prod)
@Injectable(as: ApiClient, scope: Scope.lazySingleton)
class ProductionApiClient implements ApiClient {}
```

Initialize with:

```dart
await configureDependencies(environment: Environment.prod);
```

---

## 9. `@DisposeMethod()`

Lifecycle hook automatically invoked when `getIt.reset()` or scope disposal occurs.

```dart
@Injectable(scope: Scope.lazySingleton)
class WebSocketManager {
  @DisposeMethod()
  void dispose() {
    // cleans up streams / sockets
  }
}
```

---

## 10. `@Order(int)`

Sets explicit registration precedence for classes that must be registered before others.

```dart
@Order(-10)
@Injectable(scope: Scope.singleton)
class EarlyLoggerInit {}
```
