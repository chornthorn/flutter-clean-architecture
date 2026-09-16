import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

// The cross-cutting layer: where auth, retry or metrics interceptors go.
List<Interceptor> networkInterceptors({bool logRequests = kDebugMode}) => [
  if (logRequests)
    // No bodies or headers: that is where tokens and personal data travel.
    LogInterceptor(
      requestBody: false,
      responseBody: false,
      requestHeader: false,
      responseHeader: false,
    ),
];
