import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

// The cross-cutting layer: what every request does regardless of endpoint. An
// auth, retry, or metrics interceptor joins the list here rather than in a
// feature's endpoint file.
List<Interceptor> networkInterceptors({bool logRequests = kDebugMode}) => [
  if (logRequests)
    // Method, path and status only. Bodies and headers are where tokens and
    // personal data travel, so Dio is told not to touch them.
    LogInterceptor(
      requestBody: false,
      responseBody: false,
      requestHeader: false,
      responseHeader: false,
    ),
];
