import 'package:flutter/foundation.dart';
import 'package:spi/spi.dart';

import '../execution_context.dart';
import '../execution_event.dart';
import '../execution_observer.dart';

/// Prints what each action did, in order. The dev profile's only observer.
///
/// Its output is the shortest way to see the capture working:
///
/// ```
/// ▶ ctx-7 loadPosts
///     · http-client/api
///     ✔
/// ◀ ctx-7 412ms
/// ```
class TraceObserver implements ExecutionObserver {
  const TraceObserver();

  @override
  void onExecutionEvent(ExecutionContext context, ExecutionEvent event) {
    switch (event) {
      case ExecutionStarted(:final operation):
        debugPrint('▶ ${context.id} $operation');
      case ProviderUsed(:final spi, :final id):
        debugPrint('    · $spi/$id');
      case ExecutionNoted(:final label, :final value):
        debugPrint('    ~ $label${value == null ? '' : ': $value'}');
      case ExecutionSucceeded():
        debugPrint('    ✔');
      case ExecutionFailed(:final error):
        debugPrint('    ✖ ${error.message}');
      case ExecutionClosed(:final elapsed):
        debugPrint('◀ ${context.id} ${elapsed.inMilliseconds}ms');
    }
  }

  @override
  void close() {}
}

class TraceObserverFactory implements ExecutionObserverFactory {
  const TraceObserverFactory();

  @override
  String get id => 'trace';

  @override
  int get order => defaultProviderOrder;

  /// One for the whole app: it holds nothing and reports everything.
  @override
  ProviderScope get scope => ProviderScope.application;

  @override
  ExecutionObserver create(ProviderSession session) => const TraceObserver();
}
