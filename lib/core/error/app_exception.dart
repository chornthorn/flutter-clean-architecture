/// The application-wide exception hierarchy.
///
/// Pure Dart: this file depends only on `dart:core` and carries no IO or Flutter
/// imports, so both Domain and Infrastructure may use it.
sealed class AppException implements Exception {
  const AppException({required this.message, this.statusCode, this.cause});

  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() => message;
}

/// Offline, DNS failure, or connection timeout.
final class NetworkException extends AppException {
  const NetworkException({
    super.message = 'Please check your internet connection.',
    super.statusCode,
    super.cause,
  });
}

/// 401 Unauthorized or 403 Forbidden session failure.
final class UnauthorizedException extends AppException {
  const UnauthorizedException({
    super.message = 'Session expired. Please sign in again.',
    super.statusCode = 401,
    super.cause,
  });
}

/// 404 Resource not found.
final class NotFoundException extends AppException {
  const NotFoundException({
    super.message = 'The requested item was not found.',
    super.statusCode = 404,
    super.cause,
  });
}

/// Client validation error (HTTP 400/422, or domain business validation rule failure).
final class ValidationException extends AppException {
  const ValidationException({
    required super.message,
    super.statusCode = 422,
    this.fieldErrors = const {},
    super.cause,
  });

  /// Specific field-level error messages (e.g. `{'title': 'Title cannot be empty'}`).
  final Map<String, String> fieldErrors;
}

/// 5xx Server error.
final class ServerException extends AppException {
  const ServerException({
    super.message = 'Server error. Please try again later.',
    super.statusCode,
    super.cause,
  });
}

/// Request cancelled via a cancellation token. Discarded by ViewModels.
final class CancelledException extends AppException {
  const CancelledException({
    super.message = 'The operation was cancelled.',
    super.statusCode,
    super.cause,
  });
}

/// Unhandled or unexpected fallback failure.
final class UnexpectedException extends AppException {
  const UnexpectedException({
    super.message = 'An unexpected error occurred.',
    super.statusCode,
    super.cause,
  });
}
