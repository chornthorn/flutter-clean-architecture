import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/core/async/cancellation.dart';
import 'package:flutter_x/core/error/app_exception.dart';
import 'package:flutter_x/core/networking/network_client.dart';
import 'package:flutter_x/core/networking/repository.dart';

class _TestRepository extends Repository {
  const _TestRepository();
}

void main() {
  late _TestRepository repository;

  setUp(() {
    repository = const _TestRepository();
  });

  group('Repository', () {
    group('cancelToken', () {
      test('should return null when cancellation is null', () {
        expect(repository.cancelToken(null), isNull);
      });

      test('should cancel Dio token when cancellation completes', () async {
        final source = CancellationSource();
        final token = repository.cancelToken(source.token);

        expect(token, isNotNull);
        expect(token!.isCancelled, isFalse);

        source.cancel();
        await pumpEventQueue();

        expect(token.isCancelled, isTrue);
      });
    });

    group('execute', () {
      test('should pass cancelToken and return result on success', () async {
        final source = CancellationSource();
        CancelToken? receivedToken;

        final result = await repository.execute((token) {
          receivedToken = token;
          return Future.value('success');
        }, cancellation: source.token);

        expect(result, 'success');
        expect(receivedToken, isNotNull);
      });

      test(
        'should unbox and rethrow typed AppException via .guard()',
        () async {
          final dioException = DioException(
            requestOptions: RequestOptions(path: '/items/42'),
            error: const NotFoundException(message: 'Item not found'),
          );

          final call = repository.execute<String>(
            (_) => Future<String>.error(dioException),
          );

          expect(
            call,
            throwsA(
              isA<NotFoundException>().having(
                (e) => e.message,
                'message',
                'Item not found',
              ),
            ),
          );
        },
      );

      test('should rethrow ServerException on server failure', () async {
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/items'),
          error: const ServerException(message: 'Internal server error'),
        );

        final call = repository.execute<String>(
          (_) => Future<String>.error(dioException),
        );

        expect(call, throwsA(isA<ServerException>()));
      });
    });

    group('cancellation verification end-to-end', () {
      late Dio dio;
      late _TestAdapter adapter;

      setUp(() {
        adapter = _TestAdapter();
        dio = createNetworkClient(
          baseUrl: 'https://api.test',
          logRequests: false,
        )..httpClientAdapter = adapter;
      });

      test('should cancel in-flight request and throw CancelledException when source cancels', () async {
        final source = CancellationSource();

        final inFlight = repository.execute(
          (token) => dio.get('/items', cancelToken: token),
          cancellation: source.token,
        );

        // Allow the request to reach the HTTP transport
        await pumpEventQueue();
        expect(adapter.hasPending('/items'), isTrue);

        final expectCancelled = expectLater(
          inFlight,
          throwsA(
            isA<CancelledException>().having(
              (e) => e.message,
              'message',
              'The operation was cancelled.',
            ),
          ),
        );

        // User walks away / view model disposes
        source.cancel();

        // Full pipeline verification:
        // CancellationSource -> CancelToken -> Dio cancel -> ErrorInterceptor -> .guard() -> CancelledException
        await expectCancelled;
        expect(source.isCancelled, isTrue);
      });

      test('should abort immediately with CancelledException when pre-cancelled source is passed', () async {
        final source = CancellationSource()..cancel();

        final call = repository.execute(
          (token) => dio.get('/items', cancelToken: token),
          cancellation: source.token,
        );

        await expectLater(call, throwsA(isA<CancelledException>()));
        expect(adapter.hasPending('/items'), isFalse);
      });

      test(
        'should let request complete normally when source is not cancelled',
        () async {
          final source = CancellationSource();

          final call = repository.execute(
            (token) =>
                dio.get<Map<String, dynamic>>('/items', cancelToken: token),
            cancellation: source.token,
          );

          await pumpEventQueue();
          adapter.respondJson('/items', {'status': 'ok'});

          final response = await call;
          expect(response.data, {'status': 'ok'});
          expect(source.isCancelled, isFalse);
        },
      );

      test('should isolate cancellations so cancelling one request does not affect another', () async {
        final sourceA = CancellationSource();
        final sourceB = CancellationSource();

        final callA = repository.execute(
          (token) => dio.get('/item-a', cancelToken: token),
          cancellation: sourceA.token,
        );

        final callB = repository.execute(
          (token) =>
              dio.get<Map<String, dynamic>>('/item-b', cancelToken: token),
          cancellation: sourceB.token,
        );

        await pumpEventQueue();
        expect(adapter.hasPending('/item-a'), isTrue);
        expect(adapter.hasPending('/item-b'), isTrue);

        final expectCancelledA = expectLater(
          callA,
          throwsA(isA<CancelledException>()),
        );

        // Cancel only request A
        sourceA.cancel();

        // Complete request B
        adapter.respondJson('/item-b', {'id': 'b'});

        await expectCancelledA;
        final responseB = await callB;
        expect(responseB.data, {'id': 'b'});

        expect(sourceA.isCancelled, isTrue);
        expect(sourceB.isCancelled, isFalse);
      });

      test('should complete normally when cancellation is null', () async {
        final call = repository.execute((token) {
          expect(token, isNull);
          return dio.get<Map<String, dynamic>>('/items', cancelToken: token);
        }, cancellation: null);

        await pumpEventQueue();
        adapter.respondJson('/items', {'items': []});

        final response = await call;
        expect(response.data, {'items': []});
      });
    });
  });
}

class _TestAdapter implements HttpClientAdapter {
  final Map<String, Completer<ResponseBody>> _pending = {};

  bool hasPending(String path) =>
      _pending.containsKey(path) && !_pending[path]!.isCompleted;

  void respondJson(String path, Object? body, {int status = 200}) {
    final completer = _pending[path];
    if (completer != null && !completer.isCompleted) {
      completer.complete(
        ResponseBody.fromString(
          jsonEncode(body),
          status,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        ),
      );
    }
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    final completer = Completer<ResponseBody>();
    _pending[options.path] = completer;

    cancelFuture?.then((_) {
      if (!completer.isCompleted) {
        completer.completeError(
          DioException.requestCancelled(
            requestOptions: options,
            reason: 'Request was cancelled',
          ),
        );
      }
    });

    return completer.future;
  }

  @override
  void close({bool force = false}) {}
}
