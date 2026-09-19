import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/core/error/app_exception.dart';
import 'package:flutter_x/core/networking/network_client.dart';
import 'package:flutter_x/features/posts/domain/entities/comment.dart';
import 'package:flutter_x/features/posts/infrastructure/repositories/remote_comment_repository.dart';

import 'fake_http_adapters.dart';

void main() {
  const listPayload = [
    {
      'postId': 1,
      'id': 1,
      'name': 'Ada Lovelace',
      'email': 'ada@example.com',
      'body': 'The first comment on the first post.',
    },
    {
      'postId': 1,
      'id': 2,
      'name': 'Grace Hopper',
      'email': 'grace@example.com',
      'body': 'The second comment on the first post.',
    },
  ];
  const createdPayload = {
    'postId': 1,
    'id': 501,
    'name': 'Ada Lovelace',
    'email': 'ada@example.com',
    'body': 'A new comment',
  };

  RemoteCommentRepository repositoryReturning(
    ResponseBody Function(RequestOptions options) respond, {
    HttpClientAdapter? adapter,
  }) {
    final dio = createNetworkClient(
      baseUrl: 'https://posts.test',
      logRequests: false,
    )..httpClientAdapter = adapter ?? RecordingAdapter(respond);
    return RemoteCommentRepository(dio);
  }

  group('RemoteCommentRepository', () {
    test('should read the comments under the post they belong to', () async {
      final adapter = RecordingAdapter((_) => jsonBody(listPayload));
      final repository = repositoryReturning(
        (_) => jsonBody(listPayload),
        adapter: adapter,
      );

      await repository.commentsForPost(1);

      expect(adapter.requestedMethods, ['GET']);
      expect(adapter.requestedPaths, ['/posts/1/comments']);
    });

    test('should map the payload to domain entities', () async {
      final repository = repositoryReturning((_) => jsonBody(listPayload));

      final comments = await repository.commentsForPost(1);

      expect(comments, const [
        Comment(
          id: 1,
          postId: 1,
          name: 'Ada Lovelace',
          email: 'ada@example.com',
          body: 'The first comment on the first post.',
        ),
        Comment(
          id: 2,
          postId: 1,
          name: 'Grace Hopper',
          email: 'grace@example.com',
          body: 'The second comment on the first post.',
        ),
      ]);
    });

    test('should let a read failure escape', () async {
      final repository = repositoryReturning(
        (_) => jsonBody(const {'error': 'boom'}, status: 500),
      );

      await expectLater(
        repository.commentsForPost(1),
        throwsA(isA<ServerException>()),
      );
    });

    test('should POST the create body the server expects', () async {
      final adapter = RecordingAdapter(
        (_) => jsonBody(createdPayload, status: 201),
      );
      final repository = repositoryReturning(
        (_) => jsonBody(createdPayload, status: 201),
        adapter: adapter,
      );

      await repository.createComment(
        postId: 1,
        name: 'Ada Lovelace',
        email: 'ada@example.com',
        body: 'A new comment',
      );

      expect(adapter.requestedMethods, ['POST']);
      expect(adapter.requestedPaths, ['/comments']);
      // Dio hands the adapter what `toJson` produced, so this is the payload.
      expect(adapter.requestedBodies.single, {
        'postId': 1,
        'name': 'Ada Lovelace',
        'email': 'ada@example.com',
        'body': 'A new comment',
      });
    });

    test('should map the comment the server echoes back', () async {
      final repository = repositoryReturning(
        (_) => jsonBody(createdPayload, status: 201),
      );

      final created = await repository.createComment(
        postId: 1,
        name: 'Ada Lovelace',
        email: 'ada@example.com',
        body: 'A new comment',
      );

      expect(
        created,
        const Comment(
          id: 501,
          postId: 1,
          name: 'Ada Lovelace',
          email: 'ada@example.com',
          body: 'A new comment',
        ),
      );
    });

    test('should let a rejected create escape', () async {
      final repository = repositoryReturning(
        (_) => jsonBody(const {'error': 'nope'}, status: 422),
      );

      await expectLater(
        repository.createComment(
          postId: 1,
          name: 'Ada Lovelace',
          email: 'ada@example.com',
          body: 'A new comment',
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('should drop the read when the caller walks away', () async {
      final adapter = PendingAdapter();
      final repository = repositoryReturning(
        (_) => jsonBody(listPayload),
        adapter: adapter,
      );
      final walkedAway = Completer<void>();

      final read = repository.commentsForPost(
        1,
        cancellation: walkedAway.future,
      );
      // Let the request reach the transport before pulling the plug.
      await pumpEventQueue();
      expect(adapter.cancelFuture, isNotNull);

      walkedAway.complete();

      // The read reports a cancellation, which is how the page tells it from a failure.
      await expectLater(read, throwsA(isA<CancelledException>()));
    });

    // Writes carry the token too; dropping one is the caller's call — see `core/README.md`.
    test('should drop the write when the caller walks away', () async {
      final adapter = PendingAdapter();
      final repository = repositoryReturning(
        (_) => jsonBody(createdPayload, status: 201),
        adapter: adapter,
      );
      final walkedAway = Completer<void>();

      final write = repository.createComment(
        postId: 1,
        name: 'Ada Lovelace',
        email: 'ada@example.com',
        body: 'A new comment',
        cancellation: walkedAway.future,
      );
      await pumpEventQueue();
      expect(adapter.cancelFuture, isNotNull);

      walkedAway.complete();

      await expectLater(write, throwsA(isA<CancelledException>()));
    });
  });
}
