import 'package:dio/dio.dart';

import '../error/app_exception.dart';

/// Unwraps transport-level exceptions to ensure repository callers only encounter
/// clean [AppException] instances.
extension GuardFuture<T> on Future<T> {
  /// Unwraps [DioException] to throw its attached [AppException].
  ///
  /// This keeps repositories clean and removes repetitive try-catch error mapping.
  Future<T> guard() async {
    try {
      return await this;
    } on DioException catch (e) {
      final error = e.error;
      if (error is AppException) {
        throw error;
      }
      throw UnexpectedException(
        message: e.message ?? 'An unexpected network error occurred.',
        cause: e,
      );
    }
  }
}
