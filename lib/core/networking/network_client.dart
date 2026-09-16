import 'package:dio/dio.dart';

// The app's HTTP client configuration, shared by every feature's endpoints so
// that no feature builds its own. `Dio` itself is bound in `provider.dart`.
//
// Override per build: `flutter run --dart-define=API_BASE_URL=...`.
const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://jsonplaceholder.typicode.com',
);

Dio createNetworkClient({String baseUrl = apiBaseUrl}) => Dio(
  BaseOptions(
    baseUrl: baseUrl,
    // Never wait forever on a socket.
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ),
);
