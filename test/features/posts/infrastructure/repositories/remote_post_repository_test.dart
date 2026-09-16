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
  final List<String> requestedMethods = [];
  final List<Object?> requestedBodies = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestedPaths.add(options.path);
    requestedMethods.add(options.method);
    requestedBodies.add(options.data);
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
  const createdPayload = {
    'userId': 1,
    'id': 101,
    'title': 'A new post',
    'body': 'A new body',
  };

  RemotePostRepository repositoryReturning(
    ResponseBody Function(RequestOptions options) respond, {
    _FakeAdapter? adapter,
  }) {
    final dio = createNetworkClient(
      baseUrl: 'https://posts.test',
      logRequests: false,
    )..httpClientAdapter = adapter ?? _FakeAdapter(respond);
    return RemotePostRepository(dio);
  }

  group('RemotePostRepository', () {
    test('should ask the endpoint the annotation declares', () async {
      final dio = createNetworkClient(
        baseUrl: 'https://posts.test',
        logRequests: false,
      );
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

    test('should POST the create body the server expects', () async {
      final adapter = _FakeAdapter((_) => _json(createdPayload, status: 201));
      final repository = repositoryReturning(
        (_) => _json(createdPayload, status: 201),
        adapter: adapter,
      );

      await repository.createPost(
        userId: 1,
        title: 'A new post',
        body: 'A new body',
      );

      expect(adapter.requestedMethods, ['POST']);
      expect(adapter.requestedPaths, ['/posts']);
      // Dio hands the adapter what `toJson` produced, so this is the payload.
      expect(adapter.requestedBodies.single, {
        'userId': 1,
        'title': 'A new post',
        'body': 'A new body',
      });
    });

    test('should map what the server recorded, id and all', () async {
      final repository = repositoryReturning(
        (_) => _json(createdPayload, status: 201),
      );

      final created = await repository.createPost(
        userId: 1,
        title: 'A new post',
        body: 'A new body',
      );

      expect(
        created,
        const Post(id: 101, userId: 1, title: 'A new post', body: 'A new body'),
      );
    });

    test('should let a rejected create escape', () async {
      final repository = repositoryReturning(
        (_) => _json(const {'error': 'nope'}, status: 422),
      );

      await expectLater(
        repository.createPost(userId: 1, title: 'A title', body: 'A body'),
        throwsA(isA<DioException>()),
      );
    });

    test('should PATCH an edit to the path of the post it names', () async {
      final adapter = _FakeAdapter(
        (_) => _json(const {
          'userId': 1,
          'id': 3,
          'title': 'Edited',
          'body': 'Edited body',
        }),
      );
      final repository = repositoryReturning(
        (options) => _json(const {'error': 'boom'}, status: 500),
        adapter: adapter,
      );

      final updated = await repository.updatePost(
        id: 3,
        title: 'Edited',
        body: 'Edited body',
      );

      expect(adapter.requestedMethods, ['PATCH']);
      expect(adapter.requestedPaths, ['/posts/3']);
      expect(adapter.requestedBodies.single, {
        'title': 'Edited',
        'body': 'Edited body',
      });
      expect(
        updated,
        const Post(id: 3, userId: 1, title: 'Edited', body: 'Edited body'),
      );
    });

    test('should DELETE the post at its own path', () async {
      final adapter = _FakeAdapter((_) => _json(const {}, status: 200));
      final repository = repositoryReturning(
        (_) => _json(const {}),
        adapter: adapter,
      );

      await repository.deletePost(3);

      expect(adapter.requestedMethods, ['DELETE']);
      expect(adapter.requestedPaths, ['/posts/3']);
    });

    test('should read a delete of something already gone as done', () async {
      final repository = repositoryReturning(
        (_) => _json(const {'error': 'gone'}, status: 404),
      );

      // The contract says removing what is gone is the same as removing what is
      // there, so a 404 is an outcome, not a failure.
      await expectLater(repository.deletePost(999), completes);
    });

    test('should let any other delete failure escape', () async {
      final repository = repositoryReturning(
        (_) => _json(const {'error': 'boom'}, status: 500),
      );

      await expectLater(repository.deletePost(3), throwsA(isA<DioException>()));
    });
  });
}
