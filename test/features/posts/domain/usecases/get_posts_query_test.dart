import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/posts/domain/usecases/get_posts_query.dart';
import 'package:mocktail/mocktail.dart';

import '../entities/post_fixture.dart';
import '../repositories/mock_post_repository.dart';

void main() {
  group('GetPostsQueryHandler', () {
    test('should return the posts the repository provides', () async {
      final repository = MockPostRepository();
      when(
        () => repository.allPosts(cancellation: any(named: 'cancellation')),
      ).thenAnswer((_) async => const [post]);

      final posts = await GetPostsQueryHandler(
        repository,
      ).execute(const GetPostsQuery());

      expect(posts, const [post]);
    });

    test('should let a repository failure escape', () async {
      final repository = MockPostRepository();
      when(
        () => repository.allPosts(cancellation: any(named: 'cancellation')),
      ).thenAnswer((_) async => throw Exception('offline'));

      // Holding the failure is the view model's job, not the handler's.
      await expectLater(
        GetPostsQueryHandler(repository).execute(const GetPostsQuery()),
        throwsException,
      );
    });

    test('should carry the reader\'s way out down to the repository', () async {
      final repository = MockPostRepository();
      final walkedAway = Completer<void>();
      when(
        () => repository.allPosts(cancellation: any(named: 'cancellation')),
      ).thenAnswer((_) async => const [post]);

      await GetPostsQueryHandler(
        repository,
      ).execute(GetPostsQuery(cancellation: walkedAway.future));

      // The token the screen handed the query is the one the adapter is given.
      // That handover is the whole path a cancellation travels.
      verify(
        () => repository.allPosts(cancellation: walkedAway.future),
      ).called(1);
    });
  });
}
