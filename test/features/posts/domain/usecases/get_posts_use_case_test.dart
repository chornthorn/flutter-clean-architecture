import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/posts/domain/usecases/get_posts_use_case.dart';
import 'package:mocktail/mocktail.dart';

import '../entities/post_fixture.dart';
import '../repositories/mock_post_repository.dart';

void main() {
  group('GetPostsUseCase', () {
    test('should return the posts the repository provides', () async {
      final repository = MockPostRepository();
      when(() => repository.allPosts(cancellation: any(named: 'cancellation')))
          .thenAnswer((_) async => const [post]);

      final posts = await GetPostsUseCase(repository)();

      expect(posts, const [post]);
    });

    test('should let a repository failure escape', () async {
      final repository = MockPostRepository();
      when(() => repository.allPosts(cancellation: any(named: 'cancellation')))
          .thenAnswer((_) async => throw Exception('offline'));

      // Holding the failure is the view model's job, not the use case's.
      await expectLater(GetPostsUseCase(repository)(), throwsException);
    });

    test('should carry the reader\'s way out down to the repository', () async {
      final repository = MockPostRepository();
      final walkedAway = Completer<void>();
      when(() => repository.allPosts(cancellation: any(named: 'cancellation')))
          .thenAnswer((_) async => const [post]);

      await GetPostsUseCase(repository)(cancellation: walkedAway.future);

      // The token the screen handed the use case is the one the adapter is given.
      verify(() => repository.allPosts(cancellation: walkedAway.future))
          .called(1);
    });
  });
}
