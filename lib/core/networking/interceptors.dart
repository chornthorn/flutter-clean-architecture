import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'error_interceptor.dart';

// The cross-cutting layer: where auth, retry, metrics, and error normalization go.
List<Interceptor> networkInterceptors({bool logRequests = kDebugMode}) => [
  if (logRequests)
    // No bodies or headers: that is where tokens and personal data travel.
    LogInterceptor(
      requestBody: false,
      responseBody: false,
      requestHeader: false,
      responseHeader: false,
    ),
  const ErrorInterceptor(),
];
