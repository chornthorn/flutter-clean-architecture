import 'package:spi/spi.dart';

import 'execution_context.dart';
import 'execution_event.dart';

/// SPI: who watches executions as they happen.
///
/// One SPI, one method, no phases: an observer reads the capture and does
/// whatever it likes with it. It cannot change what the user sees — that is the
/// whole point of keeping it a reader (Keycloak: `EventListenerProvider`).
class ExecutionObserverSpi implements Spi<ExecutionObserver> {
  const ExecutionObserverSpi();
  static const instance = ExecutionObserverSpi();

  @override
  String get name => 'execution-observer';

  @override
  bool accepts(ProviderFactory<dynamic> factory) =>
      factory is ExecutionObserverFactory;
}

/// Watches one screen's executions.
///
/// Registered per environment: dev prints them, prod ships them somewhere. An
/// observer must not throw; if it does, the context reports it and carries on.
abstract interface class ExecutionObserver implements Provider {
  void onExecutionEvent(ExecutionContext context, ExecutionEvent event);
}

abstract interface class ExecutionObserverFactory
    implements ProviderFactory<ExecutionObserver> {}
