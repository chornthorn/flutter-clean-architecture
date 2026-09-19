import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/posts/domain/entities/comment.dart';
import 'package:flutter_x/features/posts/domain/usecases/create_comment_command.dart';
import 'package:flutter_x/features/posts/domain/usecases/create_post_command.dart';
import 'package:flutter_x/features/posts/domain/usecases/delete_post_command.dart';
import 'package:flutter_x/features/posts/domain/usecases/get_comments_query.dart';
import 'package:flutter_x/features/posts/domain/usecases/get_post_query.dart';
import 'package:flutter_x/features/posts/domain/usecases/get_posts_query.dart';
import 'package:flutter_x/features/posts/domain/usecases/update_post_command.dart';
import 'package:mocktail/mocktail.dart';

import 'domain/entities/comment_fixture.dart';
import 'domain/entities/post_fixture.dart';
import 'domain/repositories/mock_comment_repository.dart';
import 'domain/repositories/mock_post_repository.dart';
import 'posts_dispatcher_fixture.dart';

void main() {
  const createdComment = Comment(
    id: 501,
    postId: 1,
    name: 'Alan Turing',
    email: 'alan@example.com',
    body: 'A new comment',
  );

  // The generated module binds each message to its handler; a miss throws at dispatch.
  group('PostsCqrsModule', () {
    late MockPostRepository repository;
    late MockCommentRepository comments;

    setUp(() {
      repository = MockPostRepository();
      comments = MockCommentRepository();
      when(() => repository.allPosts(cancellation: any(named: 'cancellation')))
          .thenAnswer((_) async => const [post]);
      when(
        () => repository.postById(1, cancellation: any(named: 'cancellation')),
      ).thenAnswer((_) async => post);
      when(
        () => comments.commentsForPost(
          1,
          cancellation: any(named: 'cancellation'),
        ),
      ).thenAnswer((_) async => const [comment]);
    });

    test('should dispatch every message the feature declares', () async {
      final dispatcher = postsDispatcher(repository);

      expect(await dispatcher.query(const GetPostsQuery()), const [post]);
      expect(await dispatcher.query(const GetPostQuery(1)), post);
    });

    test('should dispatch the create command', () async {
      when(
        () => repository.createPost(
          userId: any(named: 'userId'),
          title: any(named: 'title'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => post);

      final dispatcher = postsDispatcher(repository);

      final created = await dispatcher.command(
        const CreatePostCommand(userId: 1, title: 'A title', body: 'A body'),
      );

      expect(created, post);
    });

    test('should dispatch the update and delete commands', () async {
      when(
        () => repository.updatePost(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => post);
      when(() => repository.deletePost(any())).thenAnswer((_) async {});

      final dispatcher = postsDispatcher(repository);

      expect(
        await dispatcher.command(
          const UpdatePostCommand(id: 1, title: 'A title', body: 'A body'),
        ),
        post,
      );
      await dispatcher.command(const DeletePostCommand(1));

      verify(() => repository.deletePost(1)).called(1);
    });

    test('should dispatch the comments query and the create command', () async {
      when(
        () => comments.createComment(
          postId: any(named: 'postId'),
          name: any(named: 'name'),
          email: any(named: 'email'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => createdComment);

      final dispatcher = postsDispatcher(repository, comments);

      expect(await dispatcher.query(const GetCommentsQuery(1)), const [comment]);
      expect(
        await dispatcher.command(
          const CreateCommentCommand(
            postId: 1,
            name: 'Alan Turing',
            email: 'alan@example.com',
            body: 'A new comment',
          ),
        ),
        createdComment,
      );
    });
  });
}
