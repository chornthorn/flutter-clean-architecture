import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/core/error/app_exception.dart';
import 'package:flutter_x/core/execution/execution_context.dart';
import 'package:flutter_x/core/execution/execution_event.dart';
import 'package:flutter_x/core/execution/execution_observer.dart';
import 'package:flutter_x/core/execution/executions.dart';
import 'package:spi/spi.dart';

/// The capture: what it records, in what order, and what it does not change.
void main() {
  Executions executionsWith(
    Iterable<ProviderFactory<dynamic>> factories, {
    List<Spi<dynamic>> spis = const [ExecutionObserverSpi.instance],
  }) => Executions(ProviderManager(spis: spis, factories: factories));

  test('should capture an action from start to close', () async {
    final observer = RecordingObserver();
    final context = executionsWith([RecordingObserverFactory(observer)])
        .start();

    final value = await context.run(
      () async => 42,
      name: 'answer',
      args: ['q'],
    );

    expect(value, 42);
    expect(context.phase, ExecutionPhase.succeeded);
    expect(context.result, 42);
    expect(context.timeline.map((event) => event.runtimeType), [
      ExecutionStarted,
      ExecutionSucceeded,
    ]);
    expect((context.timeline.first as ExecutionStarted).operation, 'answer');
    expect((context.timeline.first as ExecutionStarted).args, ['q']);

    context.close();

    expect(context.phase, ExecutionPhase.closed);
    expect(context.isClosed, isTrue);
    expect(context.timeline.last, isA<ExecutionClosed>());
    expect(observer.seen.map((event) => event.runtimeType), [
      ExecutionStarted,
      ExecutionSucceeded,
      ExecutionClosed,
    ]);
  });

  test('should name the action after the calling method', () async {
    final context = executionsWith(const []).start();

    await _Screen().loadPosts(context);

    expect((context.timeline.first as ExecutionStarted).operation, 'loadPosts');
  });

  test('should capture a failure and rethrow it', () async {
    final context = executionsWith(const []).start();

    await expectLater(
      context.run<void>(
        () async => throw const ValidationException(message: 'Nope.'),
      ),
      throwsA(isA<ValidationException>()),
    );

    expect(context.phase, ExecutionPhase.failed);
    expect(context.error?.message, 'Nope.');
    expect(context.timeline.last, isA<ExecutionFailed>());
  });

  test('should capture a failure the body handled itself', () async {
    final context = executionsWith(const []).start();

    await context.run(() async {
      try {
        throw const NetworkException();
      } on AppException catch (error) {
        context.fail(error);
      }
    });

    expect(context.phase, ExecutionPhase.failed);
    expect(context.timeline.last, isA<ExecutionFailed>());
  });

  test('should capture the providers the screen asked for', () async {
    final context = executionsWith(
      [
        RecordingObserverFactory(RecordingObserver()),
        RecordingProviderFactory(),
      ],
      spis: const [ExecutionObserverSpi.instance, RecordingSpi.instance],
    ).start();

    context.provider(RecordingSpi.instance);

    expect(
      context.timeline.whereType<ProviderUsed>().map(
        (event) => '${event.spi}/${event.id}',
      ),
      ['recording/default'],
    );
  });

  test('should refuse to run once the screen is closed', () async {
    final context = executionsWith(const []).start();
    context.close();

    await expectLater(
      context.run(() async => 1),
      throwsA(isA<CancelledException>()),
    );
    expect(context.timeline.whereType<ExecutionStarted>(), isEmpty);
  });

  test(
    'should cancel the token and close its providers exactly once',
    () async {
      final context = executionsWith([
        RecordingObserverFactory(RecordingObserver()),
      ]).start();

      context.close();
      context.close();

      await expectLater(context.cancellation, completes);
      expect(context.isCancelled, isTrue);
      expect(context.timeline.whereType<ExecutionClosed>(), hasLength(1));
    },
  );

  test('should keep what a caller stashed in the context', () async {
    final context = executionsWith(const []).start();

    context.data['cacheKey'] = 'posts:list';
    context.note('cache.miss');

    expect(context.data['cacheKey'], 'posts:list');
    expect(
      context.timeline.whereType<ExecutionNoted>().single.label,
      'cache.miss',
    );
  });

  test('should keep going when an observer throws', () async {
    final reported = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);

    final context = executionsWith([
      RecordingObserverFactory(_ThrowingObserver()),
    ]).start();

    await context.run(() async => 1);

    expect(context.phase, ExecutionPhase.succeeded);
    expect(context.timeline, hasLength(2));
    expect(reported, hasLength(2));
  });

  test('should freeze the capture once the screen is closed', () async {
    final context = executionsWith(const []).start();
    final pending = Completer<int>();

    final action = context.run(() => pending.future);
    context.close();
    pending.complete(7);

    expect(await action, 7);
    expect(context.phase, ExecutionPhase.closed);
    expect(context.result, isNull);
    expect(context.timeline.last, isA<ExecutionClosed>());

    context.note('too late');
    expect(context.timeline.whereType<ExecutionNoted>(), isEmpty);
  });
}

/// A method, so the operation name has a caller's frame to read.
/// A method, so the operation name has a caller's frame to read — the shape every
/// view model has.
class _Screen {
  Future<void> loadPosts(ExecutionContext context) async {
    await context.run(() async {});
  }
}

class RecordingObserver implements ExecutionObserver {
  final seen = <ExecutionEvent>[];

  @override
  void onExecutionEvent(ExecutionContext context, ExecutionEvent event) =>
      seen.add(event);

  @override
  void close() {}
}

class _ThrowingObserver implements ExecutionObserver {
  @override
  void onExecutionEvent(ExecutionContext context, ExecutionEvent event) =>
      throw StateError('observer bug');

  @override
  void close() {}
}

class RecordingObserverFactory implements ExecutionObserverFactory {
  RecordingObserverFactory(this.observer);

  final ExecutionObserver observer;

  @override
  String get id => 'recording';

  @override
  int get order => defaultProviderOrder;

  @override
  ProviderScope get scope => ProviderScope.session;

  @override
  ExecutionObserver create(ProviderSession session) => observer;
}

class RecordingSpi implements Spi<RecordingProvider> {
  const RecordingSpi();
  static const instance = RecordingSpi();

  @override
  String get name => 'recording';

  @override
  bool accepts(ProviderFactory<dynamic> factory) =>
      factory is RecordingProviderFactory;
}

class RecordingProvider implements Provider {
  @override
  void close() {}
}

class RecordingProviderFactory implements ProviderFactory<RecordingProvider> {
  @override
  String get id => 'default';

  @override
  int get order => defaultProviderOrder;

  @override
  ProviderScope get scope => ProviderScope.session;

  @override
  RecordingProvider create(ProviderSession session) => RecordingProvider();
}
