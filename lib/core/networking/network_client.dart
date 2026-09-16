import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'interceptors.dart';

// Builds the client every feature shares; `Dio` is bound in `provider.dart`.
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://jsonplaceholder.typicode.com',
);

Dio createNetworkClient({
  String baseUrl = apiBaseUrl,
  bool logRequests = kDebugMode,
}) => Dio(
  BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ),
)..interceptors.addAll(networkInterceptors(logRequests: logRequests));
