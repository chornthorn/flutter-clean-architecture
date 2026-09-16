import 'package:cqrs/cqrs.dart';
import 'package:injectify/injectify.dart';

import 'cqrs_init.dart';
import 'dependency_container.config.dart';

// The app's dependency container. `useMicroPackage: true` makes `init` discover
// and compose every `@InjectableMicroPackage` under `features/`.
final getIt = GetIt.instance;

// Registers everything the app needs. Call from `main()`, before the first frame.
@InjectableInit(
  initializerName: 'init',
  preferRelativeImports: true,
  asExtension: true,
  useMicroPackage: true,
)
Future<void> configureDependencies({String? environment}) async =>
    getIt.init(environment: environment);

// The app-level CQRS binding. Handlers are resolved from the locator per
// dispatch, not held here, so a handler registered after this point is still
// reachable — the module only stores the locator.
@ExternalModule()
abstract class CqrsModule {
  @Injectable(scope: Scope.lazySingleton)
  CqrsDispatcher dispatcher() =>
      CqrsDispatcher()
        ..registry.registerModule(AppCqrsModule.fromLocator(getIt.get));
}
