import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/core/async/cancellation.dart';
import 'package:flutter_x/core/error/app_exception.dart';
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
  });
}
