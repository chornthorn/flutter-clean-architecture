import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/core/networking/network_client.dart';
import 'package:flutter_x/features/posts/domain/entities/post.dart';
import 'package:flutter_x/features/posts/infrastructure/repositories/remote_post_repository.dart';

// Answers requests from a canned payload instead of a socket, so the generated
// client is exercised without a network.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respond);

  final ResponseBody Function(RequestOptions options) respond;

  final List<String> requestedPaths = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedPaths.add(options.path);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object payload, {int status = 200}) =>
    ResponseBody.fromString(
      jsonEncode(payload),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

void main() {
  const listPayload = [
    {'userId': 1, 'id': 1, 'title': 'First post', 'body': 'Body one'},
    {'userId': 2, 'id': 2, 'title': 'Second post', 'body': 'Body two'},
  ];

  RemotePostRepository repositoryReturning(
    ResponseBody Function(RequestOptions options) respond,
  ) {
    final dio = createNetworkClient(baseUrl: 'https://posts.test')
      ..httpClientAdapter = _FakeAdapter(respond);
    return RemotePostRepository(dio);
  }

  group('RemotePostRepository', () {
    test('should ask the endpoint the annotation declares', () async {
      final dio = createNetworkClient(baseUrl: 'https://posts.test');
      final adapter = _FakeAdapter((_) => _json(listPayload));
      dio.httpClientAdapter = adapter;

      await RemotePostRepository(dio).allPosts();

      expect(adapter.requestedPaths, ['/posts']);
    });

    test('should map the payload to domain entities', () async {
      final repository = repositoryReturning((_) => _json(listPayload));

      final posts = await repository.allPosts();

      expect(posts, const [
        Post(id: 1, userId: 1, title: 'First post', body: 'Body one'),
        Post(id: 2, userId: 2, title: 'Second post', body: 'Body two'),
      ]);
    });

    test('should read one post by id', () async {
      final repository = repositoryReturning(
        (options) => _json(listPayload.first),
      );

      expect(
        await repository.postById(1),
        const Post(id: 1, userId: 1, title: 'First post', body: 'Body one'),
      );
    });

    test('should read the contract\'s null out of a 404', () async {
      final repository = repositoryReturning(
        (options) => _json(const {'error': 'not found'}, status: 404),
      );

      expect(await repository.postById(999), isNull);
    });

    test('should let any other failure escape', () async {
      final repository = repositoryReturning(
        (options) => _json(const {'error': 'boom'}, status: 500),
      );

      await expectLater(repository.postById(1), throwsA(isA<DioException>()));
    });
  });
}
