import 'package:cqrs_codegen/cqrs_codegen.dart';
import 'package:dio/dio.dart';
import 'package:injectify/injectify.dart';

import 'core/networking/network_client.dart';
import 'features/posts/posts_handler.dart';
import 'features/shop/shop_handler.dart';
import 'provider.config.dart';
import 'provider.cqrs.dart';

// The app's container. See `docs/architecture.md` for the DI rules.
final getIt = GetIt.instance;

// Registers everything the app needs, before the first frame. `environment` is
// required: an unset one registers every variant and GetIt rejects the duplicate.
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
@CqrsInit(
  moduleName: 'App',
  useMicroPackage: true,
  generateInjectable: true,
  modules: [ShopCqrsModule, PostsCqrsModule],
)
void configureCqrs() {}

// App-level bindings — no feature owns them, so they are provided through an
// `@ExternalModule` beside the container.
@ExternalModule()
abstract class AppModule {
  @Injectable(scope: Scope.lazySingleton)
  CqrsDispatcher dispatcher() {
    return CqrsDispatcher()
      ..registry.registerModule(AppCqrsModule.fromLocator(getIt.get));
  }

  // One client for every feature: timeouts and interceptors configured once.
  @Injectable(scope: Scope.lazySingleton)
  Dio dio() => createNetworkClient();
}
