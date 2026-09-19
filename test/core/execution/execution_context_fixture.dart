import 'package:flutter_x/core/execution/execution_context.dart';
import 'package:spi/spi.dart';

/// The scope a test hands a view model it builds by hand.
///
/// The app's scope comes from DI (`Scope.factory`) and the route closes it; a test
/// builds its own, closed by `dispose` exactly as the route would. No observers:
/// a test asserts on the behavior it is testing, not on the trace.
///
/// Pass [spis] and [factories] when the behavior under test asks the scope for a
/// provider.
ExecutionContext testContext({
  String id = 'ctx-test',
  List<Spi<dynamic>> spis = const [],
  List<ProviderFactory<dynamic>> factories = const [],
}) => ExecutionContext(
  providerManager: ProviderManager(spis: spis, factories: factories),
  id: id,
);
