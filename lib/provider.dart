import 'package:cqrs_codegen/cqrs_codegen.dart';
import 'package:injectify/injectify.dart';

import 'features/shop/shop_handler.dart';
import 'provider.config.dart';
import 'provider.cqrs.dart';

export 'provider.cqrs.dart';

// The app's container. `useMicroPackage: true` makes `init` discover and compose
// every `@InjectableMicroPackage` under `features/`.
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

// The app's CQRS entry point: a compositor over each feature's handler module.
// `generateInjectable` emits `AppCqrsModule.fromLocator`, which is how the
// dispatcher below is wired in one line.
@CqrsInit(
  moduleName: 'App',
  useMicroPackage: true,
  generateInjectable: true,
  modules: [ShopCqrsModule],
)
void configureCqrs() {}

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
