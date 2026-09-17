import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/core/error/app_exception.dart';
import 'package:flutter_x/core/networking/error_interceptor.dart';

void main() {
  group('ErrorInterceptor', () {
    late ErrorInterceptor interceptor;

    setUp(() {
      interceptor = const ErrorInterceptor();
    });

    DioException makeDioException({
      DioExceptionType type = DioExceptionType.badResponse,
      int? statusCode,
      dynamic data,
    }) {
      final requestOptions = RequestOptions(path: '/test');
      return DioException(
        requestOptions: requestOptions,
        type: type,
        response: statusCode != null
            ? Response(
                requestOptions: requestOptions,
                statusCode: statusCode,
                data: data,
              )
            : null,
      );
    }

    Future<DioException> runInterceptor(DioException error) async {
      DioException? captured;
      interceptor.onError(
        error,
        _CapturingHandler((rejected) => captured = rejected),
      );
      return captured!;
    }

    test('should map DioExceptionType.cancel to CancelledException', () async {
      final dioError = makeDioException(type: DioExceptionType.cancel);
      final result = await runInterceptor(dioError);

      expect(result.error, isA<CancelledException>());
      expect(
        (result.error as CancelledException).message,
        'The operation was cancelled.',
      );
    });

    test('should map connection timeouts to NetworkException', () async {
      final dioError = makeDioException(
        type: DioExceptionType.connectionTimeout,
      );
      final result = await runInterceptor(dioError);

      expect(result.error, isA<NetworkException>());
    });

    test('should map 401 to UnauthorizedException', () async {
      final dioError = makeDioException(
        statusCode: 401,
        data: {'message': 'Token expired'},
      );
      final result = await runInterceptor(dioError);

      expect(result.error, isA<UnauthorizedException>());
      expect((result.error as UnauthorizedException).message, 'Token expired');
      expect((result.error as UnauthorizedException).statusCode, 401);
    });

    test('should map 403 to UnauthorizedException', () async {
      final dioError = makeDioException(
        statusCode: 403,
        data: {'error': 'Forbidden access'},
      );
      final result = await runInterceptor(dioError);

      expect(result.error, isA<UnauthorizedException>());
      expect(
        (result.error as UnauthorizedException).message,
        'Forbidden access',
      );
      expect((result.error as UnauthorizedException).statusCode, 403);
    });

    test('should map 404 to NotFoundException', () async {
      final dioError = makeDioException(
        statusCode: 404,
        data: {'message': 'Item not found'},
      );
      final result = await runInterceptor(dioError);

      expect(result.error, isA<NotFoundException>());
      expect((result.error as NotFoundException).message, 'Item not found');
      expect((result.error as NotFoundException).statusCode, 404);
    });

    test('should map 422 with field errors to ValidationException', () async {
      final dioError = makeDioException(
        statusCode: 422,
        data: {
          'message': 'Invalid input',
          'errors': {'title': 'Title is required', 'body': 'Body is too short'},
        },
      );
      final result = await runInterceptor(dioError);

      expect(result.error, isA<ValidationException>());
      final validationException = result.error as ValidationException;
      expect(validationException.message, 'Invalid input');
      expect(validationException.fieldErrors, {
        'title': 'Title is required',
        'body': 'Body is too short',
      });
      expect(validationException.statusCode, 422);
    });

    test('should map 500 to ServerException', () async {
      final dioError = makeDioException(
        statusCode: 500,
        data: 'Internal server error',
      );
      final result = await runInterceptor(dioError);

      expect(result.error, isA<ServerException>());
      expect((result.error as ServerException).statusCode, 500);
    });

    test(
      'should fallback to UnexpectedException for unexpected status code',
      () async {
        final dioError = makeDioException(
          statusCode: 418, // I'm a teapot
          data: {'message': 'I am a teapot'},
        );
        final result = await runInterceptor(dioError);

        expect(result.error, isA<UnexpectedException>());
        expect((result.error as UnexpectedException).message, 'I am a teapot');
        expect((result.error as UnexpectedException).statusCode, 418);
      },
    );
  });
}

class _CapturingHandler extends ErrorInterceptorHandler {
  _CapturingHandler(this._onReject);

  final void Function(DioException) _onReject;

  @override
  void reject(DioException error, [bool isCallback = false]) {
    _onReject(error);
  }

  @override
  void next(DioException error) {
    _onReject(error);
  }
}
