# Troubleshooting & Diagnostics

Common issues, generator errors, and debugging strategies for `injectify` and `injectify_generator`.

---

## 1. Circular Dependency Detected

### Symptom

Resolving the first instance from `GetIt` throws or hangs at runtime because two classes depend on each other through their constructors (e.g., `ServiceA` requires `ServiceB` which requires `ServiceA`).

### Cause

Two or more classes depend on each other through constructor parameters.

### Solution

- Refactor the code to break the cycle by extracting shared logic into a separate `ServiceC` or repository.
- Use an interface or event bus/stream instead of direct bi-directional constructor coupling.
- If necessary, pass one dependency via a method call rather than in the constructor.

> Note: the generator does not perform a topological sort or cycle detection — it emits registrations in `@Order` priority order and GetIt resolves factories lazily. Cycles surface at runtime when an instance is first requested.

---

## 2. Double Registration / "Object/factory already registered in GetIt"

### Symptom

Runtime exception `StateError: Object/factory with type X is already registered in GetIt`.

### Cause

A micro-package is composed more than once:

- The parent micro-package composed it with `useMicroPackage: true` AND the root `injection.dart` composed it again.
- Or `@InjectableInit(externalMicroPackages: [...])` registered a module that was also registered manually in `main()`.

### Solution

- Adhere strictly to the **Single Composition Rule**:
  - If a nested micro-package is auto-composed by its parent module (`useMicroPackage: true`), remove any duplicate reference in the root container.
  - Avoid manually composing a module (e.g. via its generated extension `initX()`) if it is already included in `externalMicroPackages` or discovered by the root compositor.

---

## 3. Unresolved Type / Missing Dependency

### Symptom

Generated code contains `gh<dynamic>()` or compilation error: `Couldn't find constructor for Type`.

### Cause

- A dependency parameter type is not annotated with `@Injectable()` or provided by an `@ExternalModule()`.
- Or the dependency belongs to a different folder micro-package and is not public / not accessible.

### Solution

- Ensure the missing type is annotated with `@Injectable(scope: ...)`.
- If it is a third-party class, add a getter or method in an `@ExternalModule()`.
- Check import visibility across folders/packages.

---

## 4. Pending Future / Async GetIt Throws

### Symptom

Calling `getIt<Database>()` throws `StateError: Database has not been initialized or is still pending`.

### Cause

`Database` is an asynchronous singleton (`Future<T>` member or `@PreResolve`), but the app tried to resolve it synchronously **before** calling `await getIt.allReady()` (or `getIt.getAsync<T>()`).

### Solution

- After `await configureDependencies()`, wait for all pending async singletons before the first synchronous lookup:
  ```dart
  void main() async {
    WidgetsFlutterBinding.ensureInitialized();
    await configureDependencies();
    await getIt.allReady();
    runApp(const MyApp());
  }
  ```
- If the dependency is resolved before all singletons are ready, use `await getIt.getAsync<Database>()` instead.

> Note: `configureDependencies()` / `getIt.init()` only _registers_ async singletons — it does not run their factories to completion. Always await `allReady()` (or `getAsync`) before synchronous `getIt<T>()` lookups.

---

## 5. Build Runner Cache Issues

### Symptom

Code generator does not reflect recent changes, or builds fail with stale file errors.

### Solution

Clean the build cache and regenerate:

```bash
# Dart
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```
