import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/core/error/app_exception.dart';
import 'package:flutter_x/features/posts/domain/entities/post.dart';
import 'package:flutter_x/features/posts/domain/usecases/create_post_command.dart';
import 'package:mocktail/mocktail.dart';

import '../repositories/mock_post_repository.dart';

void main() {
  group('CreatePostCommandHandler', () {
    late MockPostRepository posts;
    late CreatePostCommandHandler handler;

    setUp(() {
      posts = MockPostRepository();
      when(
        () => posts.createPost(
          userId: any(named: 'userId'),
          title: any(named: 'title'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (invocation) async => Post(
          id: 101,
          userId: invocation.namedArguments[#userId] as int,
          title: invocation.namedArguments[#title] as String,
          body: invocation.namedArguments[#body] as String,
        ),
      );
      handler = CreatePostCommandHandler(posts);
    });

    test('should hand the store what the command carries', () async {
      final created = await handler.execute(
        const CreatePostCommand(userId: 1, title: 'A title', body: 'A body'),
      );

      expect(created.id, 101);
      verify(
        () => posts.createPost(userId: 1, title: 'A title', body: 'A body'),
      ).called(1);
    });

    test('should trim what the form collected', () async {
      await handler.execute(
        const CreatePostCommand(
          userId: 1,
          title: '  A title  ',
          body: '  A body  ',
        ),
      );

      verify(
        () => posts.createPost(userId: 1, title: 'A title', body: 'A body'),
      ).called(1);
    });

    test('should reject a post with no title', () async {
      await expectLater(
        handler.execute(
          const CreatePostCommand(userId: 1, title: '   ', body: 'A body'),
        ),
        throwsA(isA<ValidationException>()),
      );

      verifyNever(
        () => posts.createPost(
          userId: any(named: 'userId'),
          title: any(named: 'title'),
          body: any(named: 'body'),
        ),
      );
    });
  });
}
