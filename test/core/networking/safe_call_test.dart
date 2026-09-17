import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/core/error/app_exception.dart';
import 'package:flutter_x/core/networking/safe_call.dart';

void main() {
  group('GuardFuture extension', () {
    test('should return value when future succeeds', () async {
      final result = await Future.value('success').guard();
      expect(result, 'success');
    });

    test(
      'should rethrow unwrapped AppException when DioException holds AppException',
      () async {
        final appException = const NotFoundException(message: 'Post missing');
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/posts/1'),
          error: appException,
        );

        final future = Future<String>.error(dioException).guard();

        expect(
          future,
          throwsA(
            isA<NotFoundException>().having(
              (e) => e.message,
              'message',
              'Post missing',
            ),
          ),
        );
      },
    );

    test(
      'should wrap raw DioException without AppException into UnexpectedException',
      () async {
        final dioException = DioException(
          requestOptions: RequestOptions(path: '/posts/1'),
          message: 'Something went wrong',
        );

        final future = Future<String>.error(dioException).guard();

        expect(future, throwsA(isA<UnexpectedException>()));
      },
    );

    test('should rethrow non-Dio exceptions directly', () async {
      final formatException = const FormatException('Invalid json');

      final future = Future<String>.error(formatException).guard();

      expect(future, throwsA(isA<FormatException>()));
    });
  });
}
