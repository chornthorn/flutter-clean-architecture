import 'package:cqrs_codegen/cqrs_codegen.dart';
import 'package:dio/dio.dart';
import 'package:injectify/injectify.dart';
import 'package:spi/spi.dart';

import 'core/execution/execution_context.dart';
import 'core/execution/execution_observer.dart';
import 'core/execution/executions.dart';
import 'core/execution/observers/trace_observer.dart';
import 'core/networking/network_client.dart';
import 'features/posts/posts_handler.dart';
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
@CqrsInit(
  moduleName: 'App',
  useMicroPackage: true,
  generateInjectable: true,
  modules: [ShopCqrsModule, PostsCqrsModule],
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

  // One client for every feature: timeouts and interceptors configured once.
  @Injectable(scope: Scope.lazySingleton)
  Dio dio() => createNetworkClient();

  // The execution capture: one provider registration for the app, one scope per
  // screen. What runs in it — observers today, policies later — is registered
  // here and nowhere else.
  @Injectable(scope: Scope.lazySingleton)
  Executions executions(ExecutionObservers observers) => Executions(
    ProviderManager(
      spis: const [ExecutionObserverSpi.instance],
      factories: observers.factories,
    ),
  );

  // `Scope.factory` is what makes the scope per screen: every view model asks
  // once and gets its own, and its route closes it.
  @Injectable(scope: Scope.factory)
  ExecutionContext executionContext(Executions executions) =>
      executions.start();
}

/// Which execution observers an environment runs.
abstract interface class ExecutionObservers {
  List<ExecutionObserverFactory> get factories;
}

/// Dev prints every action, so the capture is visible while the app runs.
@Environment(Environment.dev)
@Injectable(as: ExecutionObservers, scope: Scope.lazySingleton)
class DevExecutionObservers implements ExecutionObservers {
  const DevExecutionObservers();

  @override
  List<ExecutionObserverFactory> get factories => const [
    TraceObserverFactory(),
  ];
}

/// Prod has nowhere to send them yet, and tests record their own. Register the
/// first real one here rather than inside the context.
@Environment(Environment.prod)
@Environment(Environment.test)
@Injectable(as: ExecutionObservers, scope: Scope.lazySingleton)
class QuietExecutionObservers implements ExecutionObservers {
  const QuietExecutionObservers();

  @override
  List<ExecutionObserverFactory> get factories => const [];
}
