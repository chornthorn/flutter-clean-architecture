import 'package:spi/spi.dart';

import 'execution_context.dart';

/// Creates one execution context per screen and owns the app's providers.
///
/// The manager is built once at startup — that is where the observers and every
/// other provider are registered — and each view model asks [start] for its own
/// scope through DI.
final class Executions {
  Executions(this.providerManager);

  /// The app's provider registration: created at startup, closed at teardown.
  final ProviderManager providerManager;

  int _sequence = 0;

  ExecutionContext start({ExecutionOrigin origin = ExecutionOrigin.tap}) =>
      ExecutionContext(
        providerManager: providerManager,
        id: 'ctx-${++_sequence}',
        origin: origin,
      );
}
