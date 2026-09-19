import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/core/execution/execution_context.dart';
import 'package:flutter_x/features/posts/presentation/view_models/post_view_model.dart';
import 'package:flutter_x/provider.dart';
import 'package:injectify/injectify.dart';

/// How the app wires the capture: one provider registration for the app, one
/// scope per screen, and the observers of the environment it runs in.
void main() {
  setUp(() async => getIt.reset());

  test('should hand each screen its own scope', () async {
    await configureDependencies(environment: Environment.test);

    final first = getIt<ExecutionContext>();
    final second = getIt<ExecutionContext>();

    expect(first, isNot(same(second)));
    expect(first.id, isNot(second.id));
    // One registration behind both: the app's providers are built once.
    expect(first.providerManager, same(second.providerManager));
  });

  test('should give a view model the scope its route closes', () async {
    await configureDependencies(environment: Environment.test);

    final viewModel = getIt<PostViewModel>();

    expect(viewModel.context.host, PostViewModel);
    expect(viewModel.isDisposed, isFalse);

    viewModel.dispose();

    expect(viewModel.isDisposed, isTrue);
    expect(viewModel.context.isClosed, isTrue);
  });

  test('should register the observers of the environment it runs in', () async {
    await configureDependencies(environment: Environment.dev);
    expect(getIt<ExecutionObservers>(), isA<DevExecutionObservers>());

    await getIt.reset();
    await configureDependencies(environment: Environment.test);
    expect(getIt<ExecutionObservers>(), isA<QuietExecutionObservers>());
  });
}
