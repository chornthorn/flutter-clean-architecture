import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/posts/domain/repositories/comment_repository.dart';
import 'package:flutter_x/features/posts/domain/repositories/post_repository.dart';
import 'package:flutter_x/features/posts/domain/usecases/get_comments_use_case.dart';
import 'package:flutter_x/features/posts/domain/usecases/get_posts_use_case.dart';
import 'package:flutter_x/features/posts/infrastructure/repositories/in_memory_comment_repository.dart';
import 'package:flutter_x/features/posts/infrastructure/repositories/in_memory_post_repository.dart';
import 'package:flutter_x/features/posts/infrastructure/repositories/remote_comment_repository.dart';
import 'package:flutter_x/features/posts/infrastructure/repositories/remote_post_repository.dart';
import 'package:flutter_x/provider.dart';
import 'package:injectify/injectify.dart';

import 'domain/entities/comment_fixture.dart';
import 'domain/entities/post_fixture.dart';

void main() {
  setUp(() async => getIt.reset());

  // The feature's source is a choice, so which adapter each environment gets is pinned here.
  group('PostRepository binding', () {
    test('should read the fixture in dev', () async {
      await configureDependencies(environment: Environment.dev);

      expect(getIt<PostRepository>(), isA<InMemoryPostRepository>());
    });

    test('should read the fixture in test', () async {
      await configureDependencies(environment: Environment.test);

      expect(getIt<PostRepository>(), isA<InMemoryPostRepository>());
    });

    test('should read over HTTP in prod', () async {
      await configureDependencies(environment: Environment.prod);

      expect(getIt<PostRepository>(), isA<RemotePostRepository>());
    });
  });

  test(
    'should serve the list through the container without a network',
    () async {
      await configureDependencies(environment: Environment.test);

      final posts = await getIt<GetPostsUseCase>()();

      expect(posts, contains(post));
    },
  );

  // The comments behind a post are a second contract, chosen by environment the
  // same way the posts one is.
  group('CommentRepository binding', () {
    test('should read the fixture in dev', () async {
      await configureDependencies(environment: Environment.dev);

      expect(getIt<CommentRepository>(), isA<InMemoryCommentRepository>());
    });

    test('should read the fixture in test', () async {
      await configureDependencies(environment: Environment.test);

      expect(getIt<CommentRepository>(), isA<InMemoryCommentRepository>());
    });

    test('should read over HTTP in prod', () async {
      await configureDependencies(environment: Environment.prod);

      expect(getIt<CommentRepository>(), isA<RemoteCommentRepository>());
    });
  });

  test(
    'should serve a thread through the container without a network',
    () async {
      await configureDependencies(environment: Environment.test);

      final comments = await getIt<GetCommentsUseCase>()(1);

      expect(comments, contains(comment));
    },
  );
}
