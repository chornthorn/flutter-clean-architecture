import 'package:cqrs_codegen/cqrs_codegen.dart';
import 'package:dio/dio.dart';
import 'package:injectify/injectify.dart';

import 'core/networking/network_client.dart';
import 'features/shop/shop_handler.dart';
import 'provider.config.dart';
import 'provider.cqrs.dart';

// The app's container. See `docs/architecture.md` for the DI rules.
final getIt = GetIt.instance;

// Required: when unset, every variant registers and GetIt rejects the duplicate.
@InjectableInit(
  initializerName: 'init',
  preferRelativeImports: true,
  asExtension: true,
  useMicroPackage: true,
)
Future<void> configureDependencies({required String environment}) async {
  getIt.init(environment: environment);
}

// The app's CQRS entry point: a compositor over each feature's handler module.
//
// Only the module that still carries a message appears here. Both features
// reach the domain through the use cases their view models are built with;
// shop keeps one event, which is the module-to-module traffic CQRS is here for.
@CqrsInit(
  moduleName: 'App',
  useMicroPackage: true,
  generateInjectable: true,
  modules: [ShopCqrsModule],
)
void configureCqrs() {}

// App-level bindings no feature owns, so they sit behind an `@ExternalModule`.
@ExternalModule()
abstract class AppModule {
  @Injectable(scope: Scope.lazySingleton)
  CqrsDispatcher dispatcher() {
    return CqrsDispatcher()
      ..registry.registerModule(AppCqrsModule.fromLocator(getIt.get));
  }

  // One client for every feature: timeouts and error mapping configured once.
  @Injectable(scope: Scope.lazySingleton)
  Dio dio() => NetworkClient();
}
