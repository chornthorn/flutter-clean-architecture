import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'concurrent_request_interceptor.dart';
import 'error_interceptor.dart';

// The cross-cutting layer: where auth, retry, metrics, and error normalization go.
List<Interceptor> networkInterceptors({
  bool logRequests = kDebugMode,
  Duration dedupeWindow = ConcurrentRequestInterceptor.defaultWindow,
}) => [
  if (logRequests)
    // No bodies or headers: that is where tokens and personal data travel.
    LogInterceptor(
      requestBody: false,
      responseBody: false,
      requestHeader: false,
      responseHeader: false,
    ),
  // Ahead of `ErrorInterceptor`, which rejects without calling the error
  // interceptors after it: placed behind, this one's `onError` would never run
  // and every entry it tracks would leak. Order here is load-bearing.
  ConcurrentRequestInterceptor(window: dedupeWindow),
  const ErrorInterceptor(),
];
