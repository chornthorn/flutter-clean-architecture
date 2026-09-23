import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/core/error/app_exception.dart';
import 'package:flutter_x/core/networking/concurrent_request_interceptor.dart';
import 'package:flutter_x/core/networking/error_interceptor.dart';
import 'package:flutter_x/core/networking/interceptors.dart';

/// Answers nothing, so every request stays in flight until the interceptor or
/// the test ends it.
class _PendingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requested = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requested.add(options);
    return Completer<ResponseBody>().future;
  }

  @override
  void close({bool force = false}) {}
}

/// Starts [request] and swallows whichever way it settles: one this test
/// deliberately cancels would otherwise surface as an unhandled error.
void _start(Future<dynamic> request) {
  unawaited(request.then<void>((_) {}, onError: (Object _) {}));
}

/// The error [request] fails with, or a failure naming what it returned instead.
Future<Object> _failureOf(Future<dynamic> request) => request.then<Object>(
  (value) => throw StateError('expected a failure, got $value'),
  onError: (Object error) => error,
);

void main() {
  late _PendingAdapter adapter;

  Dio buildClient({
    Duration window = ConcurrentRequestInterceptor.defaultWindow,
    Set<String> methods = ConcurrentRequestInterceptor.readMethods,
  }) {
    adapter = _PendingAdapter();
    return Dio(BaseOptions(baseUrl: 'https://example.test'))
      ..httpClientAdapter = adapter
      ..interceptors.add(
        ConcurrentRequestInterceptor(window: window, methods: methods),
      );
  }

  // The requests in flight never answer, so what a test watches is the token it
  // handed in: cancelled means the interceptor superseded that call.
  group('ConcurrentRequestInterceptor', () {
    test('should cancel the request in flight when an identical one starts', () async {
      final dio = buildClient();
      final first = CancelToken();
      final second = CancelToken();

      _start(dio.get<dynamic>('/posts', cancelToken: first));
      await pumpEventQueue();
      _start(dio.get<dynamic>('/posts', cancelToken: second));
      await pumpEventQueue();

      expect(first.isCancelled, isTrue);
      expect(second.isCancelled, isFalse, reason: 'the newcomer is left to run');
    });

    test('should keep different query parameters apart', () async {
      final dio = buildClient();
      final first = CancelToken();
      final second = CancelToken();

      _start(
        dio.get<dynamic>(
          '/posts',
          queryParameters: {'page': 1},
          cancelToken: first,
        ),
      );
      await pumpEventQueue();
      _start(
        dio.get<dynamic>(
          '/posts',
          queryParameters: {'page': 2},
          cancelToken: second,
        ),
      );
      await pumpEventQueue();

      expect(first.isCancelled, isFalse, reason: 'page 1 is not a duplicate of page 2');
      expect(second.isCancelled, isFalse);
    });

    test('should keep different paths apart', () async {
      final dio = buildClient();
      final first = CancelToken();
      final second = CancelToken();

      _start(dio.get<dynamic>('/posts', cancelToken: first));
      await pumpEventQueue();
      _start(dio.get<dynamic>('/posts/1', cancelToken: second));
      await pumpEventQueue();

      expect(first.isCancelled, isFalse);
      expect(second.isCancelled, isFalse);
    });

    test('should leave a request alone once the window has passed', () async {
      final dio = buildClient(window: const Duration(milliseconds: 30));
      final first = CancelToken();
      final second = CancelToken();

      _start(dio.get<dynamic>('/posts', cancelToken: first));
      await pumpEventQueue();
      await Future<void>.delayed(const Duration(milliseconds: 60));

      _start(dio.get<dynamic>('/posts', cancelToken: second));
      await pumpEventQueue();

      expect(first.isCancelled, isFalse, reason: 'it outlived the window');
      expect(second.isCancelled, isFalse);
    });

    test('should not evict the newer request when the superseded one finishes', () async {
      final dio = buildClient();
      final first = CancelToken();
      final second = CancelToken();
      final third = CancelToken();

      _start(dio.get<dynamic>('/posts', cancelToken: first));
      await pumpEventQueue();

      _start(dio.get<dynamic>('/posts', cancelToken: second));
      // The first is cancelled here, so it settles and runs its own cleanup.
      await pumpEventQueue();

      _start(dio.get<dynamic>('/posts', cancelToken: third));
      await pumpEventQueue();

      expect(first.isCancelled, isTrue);
      expect(
        second.isCancelled,
        isTrue,
        reason: 'the first finishing must not clear the second from the map',
      );
      expect(third.isCancelled, isFalse);
    });

    test('should not supersede a write', () async {
      final dio = buildClient();
      final first = CancelToken();
      final second = CancelToken();

      _start(dio.post<dynamic>('/posts', data: {'title': 'one'}, cancelToken: first));
      await pumpEventQueue();
      _start(dio.post<dynamic>('/posts', data: {'title': 'two'}, cancelToken: second));
      await pumpEventQueue();

      expect(first.isCancelled, isFalse, reason: 'a cancelled write is not a retry');
      expect(second.isCancelled, isFalse);
    });

    test('should supersede a write once the method is allowed', () async {
      final dio = buildClient(methods: const {'POST'});
      final first = CancelToken();
      final second = CancelToken();

      _start(dio.post<dynamic>('/posts', data: {'title': 'one'}, cancelToken: first));
      await pumpEventQueue();
      _start(dio.post<dynamic>('/posts', data: {'title': 'two'}, cancelToken: second));
      await pumpEventQueue();

      expect(first.isCancelled, isTrue);
      expect(second.isCancelled, isFalse);
    });

    test('should mint a token when the caller brought none', () async {
      final dio = buildClient();

      final superseded = _failureOf(dio.get<dynamic>('/posts'));
      await pumpEventQueue();
      _start(dio.get<dynamic>('/posts'));

      final failure = await superseded;
      expect(failure, isA<DioException>());
      expect((failure as DioException).type, DioExceptionType.cancel);
    });
  });

  group('networkInterceptors', () {
    test('should place the dedupe interceptor ahead of ErrorInterceptor', () {
      final interceptors = networkInterceptors(logRequests: false);
      final dedupe = interceptors.indexWhere(
        (interceptor) => interceptor is ConcurrentRequestInterceptor,
      );
      final errors = interceptors.indexWhere(
        (interceptor) => interceptor is ErrorInterceptor,
      );

      expect(dedupe, isNonNegative);
      expect(errors, isNonNegative);
      expect(
        dedupe,
        lessThan(errors),
        reason:
            'ErrorInterceptor rejects without calling the error interceptors '
            'after it, so the dedupe cleanup would never run from behind it',
      );
    });

    test('should report a superseded call as a cancellation end to end', () async {
      adapter = _PendingAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'))
        ..httpClientAdapter = adapter
        ..interceptors.addAll(networkInterceptors(logRequests: false));

      // No token from the caller: the interceptor mints the one it cancels.
      final superseded = _failureOf(dio.get<dynamic>('/posts'));
      await pumpEventQueue();
      _start(dio.get<dynamic>('/posts'));

      final failure = await superseded;
      expect(failure, isA<DioException>());

      final cancelled = failure as DioException;
      expect(cancelled.type, DioExceptionType.cancel);
      // Attached by `ErrorInterceptor` and unboxed by `.guard()` in
      // `Repository.execute` — the `CancelledException` a view model drops.
      expect(cancelled.error, isA<CancelledException>());
    });
  });
}
