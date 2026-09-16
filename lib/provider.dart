import 'package:cqrs_codegen/cqrs_codegen.dart';
import 'package:dio/dio.dart';
import 'package:injectify/injectify.dart';

import 'core/networking/network_client.dart';
import 'features/posts/posts_handler.dart';
import 'features/shop/shop_handler.dart';
import 'provider.config.dart';
import 'provider.cqrs.dart';

// The app's container. `useMicroPackage: true` makes `init` discover and compose
// every `@InjectableMicroPackage` under `features/`.
final getIt = GetIt.instance;

// Registers everything the app needs. Call from `main()`, before the first frame.
//
// `environment` is required rather than optional: features bind one adapter per
// environment (the posts source, for one), and an unset environment registers
// every variant, which GetIt rejects as a duplicate registration.
@InjectableInit(
  initializerName: 'init',
  preferRelativeImports: true,
  asExtension: true,
  useMicroPackage: true,
)
Future<void> configureDependencies({required String environment}) async =>
    getIt.init(environment: environment);

// The app's CQRS entry point: a compositor over each feature's handler module.
// `generateInjectable` emits `AppCqrsModule.fromLocator`, which is how the
// dispatcher below is wired in one line.
@CqrsInit(
  moduleName: 'App',
  useMicroPackage: true,
  generateInjectable: true,
  modules: [ShopCqrsModule, PostsCqrsModule],
)
void configureCqrs() {}

// App-level bindings: the ones that belong to no single feature.
@ExternalModule()
abstract class AppModule {
  @Injectable(scope: Scope.lazySingleton)
  CqrsDispatcher dispatcher() =>
      CqrsDispatcher()
        ..registry.registerModule(AppCqrsModule.fromLocator(getIt.get));

  // One client for every feature's endpoints.
  @Injectable(scope: Scope.lazySingleton)
  Dio dio() => createNetworkClient();
}
