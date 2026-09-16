import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/posts/domain/usecases/get_posts_query.dart';
import 'package:mocktail/mocktail.dart';

import '../entities/post_fixture.dart';
import '../repositories/mock_post_repository.dart';

void main() {
  group('GetPostsQueryHandler', () {
    test('should return the posts the repository provides', () async {
      final repository = MockPostRepository();
      when(() => repository.allPosts()).thenAnswer((_) async => const [post]);

      final posts = await GetPostsQueryHandler(
        repository,
      ).execute(const GetPostsQuery());

      expect(posts, const [post]);
    });

    test('should let a repository failure escape', () async {
      final repository = MockPostRepository();
      when(
        () => repository.allPosts(),
      ).thenAnswer((_) async => throw Exception('offline'));

      // Holding the failure is the view model's job, not the handler's.
      await expectLater(
        GetPostsQueryHandler(repository).execute(const GetPostsQuery()),
        throwsException,
      );
    });
  });
}
