import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/core/networking/network_client.dart';

void main() {
  group('createNetworkClient', () {
    test('should point at the base URL it was given', () {
      final dio = createNetworkClient(baseUrl: 'https://posts.test');

      expect(dio.options.baseUrl, 'https://posts.test');
    });

    test('should set the timeouts that keep a call from hanging', () {
      final dio = createNetworkClient();

      expect(dio.options.connectTimeout, isNotNull);
      expect(dio.options.receiveTimeout, isNotNull);
    });

    test('should install the logging interceptor only when asked', () {
      expect(
        createNetworkClient(
          logRequests: true,
        ).interceptors.whereType<LogInterceptor>(),
        hasLength(1),
      );
      expect(
        createNetworkClient(
          logRequests: false,
        ).interceptors.whereType<LogInterceptor>(),
        isEmpty,
      );
    });
  });
}
