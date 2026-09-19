import 'package:flutter/foundation.dart';
import 'package:spi/spi.dart';

import '../async/cancellation.dart';
import '../error/app_exception.dart';
import 'execution_event.dart';
import 'execution_observer.dart';

/// Where the action came from (NestJS: `ExecutionContext.getType()`).
enum ExecutionOrigin {
  /// A user gesture — a tap, a submit.
  tap,

  /// The route opened.
  route,

  /// The app started something on its own.
  system,
}

/// What the action is doing right now.
enum ExecutionPhase { idle, running, succeeded, failed, closed }

/// One screen's execution capture and provider scope (NestJS:
/// `ExecutionContext`, Keycloak: the session).
///
/// It records while the work happens — the action's name, the providers it asked
/// for, notes anyone adds, how it ended — and it owns every provider the screen
/// created, so [close] releases all of it. It decides nothing: an observer reads
/// the capture, and policy arrives later as another provider that reads the same
/// timeline.
///
/// One per view model, created by DI and closed by the route that owns it.
final class ExecutionContext extends DefaultProviderSession {
  ExecutionContext({
    required super.providerManager,
    required this.id,
    this.origin = ExecutionOrigin.tap,
    DateTime? startedAt,
  }) : _startedAt = startedAt ?? DateTime.now();

  /// `ctx-7` — auto, unique per app run.
  final String id;

  final ExecutionOrigin origin;
  final DateTime _startedAt;

  /// Who is running it, e.g. `PostViewModel`. Set by the `ViewModel` base.
  Type? host;

  /// Everything captured, in order.
  final List<ExecutionEvent> timeline = [];

  /// The bag: whoever holds the context stashes what someone else should read.
  final Map<String, Object?> data = {};

  final _cancellation = CancellationSource();
  ExecutionPhase _phase = ExecutionPhase.idle;
  Object? _result;
  AppException? _error;
  Duration? _elapsed;

  ExecutionPhase get phase => _phase;

  /// What the last action returned, when it returned.
  Object? get result => _result;

  /// What the last action threw, when it threw.
  AppException? get error => _error;

  /// Since the screen opened — finished when it closed.
  Duration get elapsed => _elapsed ?? DateTime.now().difference(_startedAt);

  /// The token a port takes: it completes when the route pops.
  Cancellation get cancellation => _cancellation.token;

  /// Whether the route is gone: what tells a dropped request from a failed one.
  bool get isCancelled => _cancellation.isCancelled;
  bool get isClosed => _phase == ExecutionPhase.closed;

  /// One action's boundary: captures the start, whatever it returns, and any
  /// [AppException] it throws — then rethrows, so the caller's error handling is
  /// untouched. The name is the calling method's.
  ///
  /// A body that catches its own errors must report them with [fail], otherwise
  /// the capture says the action succeeded.
  Future<T> run<T>(
    Future<T> Function() action, {
    String? name,
    List<Object?> args = const [],
  }) async {
    if (isClosed) throw const CancelledException();

    _phase = ExecutionPhase.running;
    _emit(
      ExecutionStarted(
        DateTime.now(),
        name ?? _operationFromStack() ?? 'action',
        args,
      ),
    );

    try {
      final value = await action();
      // The route may have popped while the work was in flight. A closed context
      // captures nothing more and never comes back to life — that is what a view
      // model reads `isDisposed` for.
      //
      // A body that reported its own failure keeps it: returning normally after
      // `fail(...)` does not turn a failure into a success.
      if (!isClosed && _phase == ExecutionPhase.running) {
        _result = value;
        _phase = ExecutionPhase.succeeded;
        _emit(ExecutionSucceeded(DateTime.now(), value));
      }
      return value;
    } on AppException catch (error) {
      if (!isClosed && _phase == ExecutionPhase.running) {
        _error = error;
        _phase = ExecutionPhase.failed;
        _emit(ExecutionFailed(DateTime.now(), error));
      }
      rethrow;
    }
  }

  /// Records a failure the body handled itself.
  void fail(AppException error) {
    if (isClosed) return;
    _error = error;
    _phase = ExecutionPhase.failed;
    _emit(ExecutionFailed(DateTime.now(), error));
  }

  /// Records anything else worth keeping.
  void note(String label, [Object? value]) {
    if (isClosed) return;
    _emit(ExecutionNoted(DateTime.now(), label, value));
  }

  /// Every provider the screen asks for is captured.
  @override
  T provider<T extends Provider>(Spi<T> spi, [String? id]) {
    final provider = super.provider(spi, id);
    // Announcing the observers would recurse: they are the announcers.
    if (identical(spi, ExecutionObserverSpi.instance)) return provider;
    _emit(ProviderUsed(DateTime.now(), spi.name, id ?? 'default'));
    return provider;
  }

  /// The route popped: stop the work, record the cost, release the scope.
  @override
  void close() {
    if (isClosed) return;

    if (!_cancellation.isCancelled) _cancellation.cancel();
    _phase = ExecutionPhase.closed;
    _elapsed = DateTime.now().difference(_startedAt);
    _emit(ExecutionClosed(DateTime.now(), _elapsed!));
    super.close();
  }

  void _emit(ExecutionEvent event) {
    timeline.add(event);
    for (final observer in providers(ExecutionObserverSpi.instance)) {
      try {
        observer.onExecutionEvent(this, event);
      } catch (error, stack) {
        // A broken observer is its own bug, and must never break the action.
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'execution context',
            context: ErrorDescription('observing ${event.runtimeType}'),
          ),
        );
      }
    }
  }
}

/// The calling method's name — `PostViewModel.loadPosts` → `loadPosts`.
///
/// Read before the first await, so the frame is still the caller's. A frame
/// reports an async body or an inlined closure as
/// `PostViewModel.loadPosts.<anonymous closure>`, so the stem is what names the
/// action. Dart strips symbols under `--obfuscate`: pass `name:` where a name must
/// survive that.
String? _operationFromStack() {
  for (final frame in StackTrace.current.toString().split('\n').skip(1)) {
    final symbol = RegExp(r'^#\d+\s+(.+?)\s+\(').firstMatch(frame.trim())?.group(1);
    if (symbol == null) continue;

    final stem = symbol.replaceAll(RegExp(r'\.<anonymous closure>$'), '');
    if (stem.startsWith('ExecutionContext') || stem.startsWith('_operationFromStack')) {
      continue;
    }

    final name = stem.split('.').last;
    if (name.isEmpty || name == 'closure' || name == 'call' || name == 'main') continue;
    return name;
  }
  return null;
}
