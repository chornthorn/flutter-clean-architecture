import 'package:dio/dio.dart';

import '../error/app_exception.dart';

/// Intercepts raw network and HTTP errors, parses backend response envelopes,
/// and attaches a normalized [AppException] to [DioException.error].
class ErrorInterceptor extends Interceptor {
  const ErrorInterceptor();

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.type == DioExceptionType.cancel) {
      handler.reject(err.copyWith(error: const CancelledException()));
      return;
    }

    final exception = _extractException(err);
    handler.reject(err.copyWith(error: exception));
  }

  AppException _extractException(DioException err) {
    return switch (err.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError => NetworkException(cause: err),

      DioExceptionType.badResponse => _fromResponse(err),

      _ => UnexpectedException(
        message: err.message ?? 'An unexpected error occurred.',
        cause: err,
      ),
    };
  }

  AppException _fromResponse(DioException err) {
    final response = err.response;
    final statusCode = response?.statusCode;
    final data = response?.data;

    String? serverMessage;
    Map<String, String> fieldErrors = const {};

    if (data is Map) {
      final msg = data['message'] ?? data['error'];
      if (msg is String && msg.trim().isNotEmpty) {
        serverMessage = msg.trim();
      }

      final errors = data['errors'];
      if (errors is Map) {
        fieldErrors = errors.map(
          (key, value) => MapEntry(key.toString(), value.toString()),
        );
      }
    }

    return switch (statusCode) {
      401 || 403 => UnauthorizedException(
        message: serverMessage ?? 'Session expired. Please sign in again.',
        statusCode: statusCode,
        cause: err,
      ),
      404 => NotFoundException(
        message: serverMessage ?? 'The requested item was not found.',
        statusCode: statusCode,
        cause: err,
      ),
      400 || 422 => ValidationException(
        message:
            serverMessage ?? 'Validation failed. Please check your inputs.',
        statusCode: statusCode ?? 422,
        fieldErrors: fieldErrors,
        cause: err,
      ),
      int s when s >= 500 => ServerException(
        message: serverMessage ?? 'Server error. Please try again later.',
        statusCode: statusCode,
        cause: err,
      ),
      _ => UnexpectedException(
        message: serverMessage ?? 'Unexpected response ($statusCode)',
        statusCode: statusCode,
        cause: err,
      ),
    };
  }
}
