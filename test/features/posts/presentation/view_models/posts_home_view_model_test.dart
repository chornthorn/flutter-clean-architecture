import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/posts/domain/entities/post.dart';
import 'package:flutter_x/features/posts/infrastructure/repositories/in_memory_post_repository.dart';
import 'package:flutter_x/features/posts/presentation/posts_watch.dart';
import 'package:flutter_x/features/posts/presentation/view_models/posts_home_view_model.dart';
import 'package:mocktail/mocktail.dart';

import '../../domain/entities/post_fixture.dart';
import '../../domain/repositories/mock_post_repository.dart';
import '../../posts_dispatcher_fixture.dart';

void main() {
  group('PostsHomeViewModel', () {
    test('should report loading until the list arrives', () async {
      final repository = MockPostRepository();
      when(() => repository.allPosts()).thenAnswer((_) async => const [post]);

      final viewModel = PostsHomeViewModel(
        postsDispatcher(repository),
        PostsWatch(),
      );
      addTearDown(viewModel.dispose);

      final load = viewModel.load();
      expect(viewModel.isLoading, isTrue);
      expect(viewModel.posts, isNull);

      await load;
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.posts, const [post]);
    });

    test('should hold a failure in error instead of throwing', () async {
      final repository = MockPostRepository();
      when(
        () => repository.allPosts(),
      ).thenAnswer((_) async => throw Exception('offline'));

      final viewModel = PostsHomeViewModel(
        postsDispatcher(repository),
        PostsWatch(),
      );
      addTearDown(viewModel.dispose);

      await expectLater(viewModel.load(), completes);

      expect(viewModel.error, isA<Exception>());
      expect(viewModel.posts, isNull);
    });

    test('should create through the command and re-read the list', () async {
      // A real store: the post shows up in the list only if the command wrote it
      // and the reload read it back.
      final store = InMemoryPostRepository();
      final viewModel = PostsHomeViewModel(
        postsDispatcher(store),
        PostsWatch(),
      );
      addTearDown(viewModel.dispose);
      await viewModel.load();

      final created = await viewModel.createPost(
        title: 'A new post',
        body: 'A new body',
      );

      expect(created, isTrue);
      expect(viewModel.error, isNull);
      expect(
        viewModel.posts,
        contains(
          const Post(id: 4, userId: 1, title: 'A new post', body: 'A new body'),
        ),
      );
    });

    test(
      'should keep the failure and answer false when a create fails',
      () async {
        final store = MockPostRepository();
        when(() => store.allPosts()).thenAnswer((_) async => const [post]);
        when(
          () => store.createPost(
            userId: any(named: 'userId'),
            title: any(named: 'title'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => throw Exception('offline'));

        final viewModel = PostsHomeViewModel(
          postsDispatcher(store),
          PostsWatch(),
        );
        addTearDown(viewModel.dispose);
        await viewModel.load();

        final created = await viewModel.createPost(
          title: 'A new post',
          body: 'A new body',
        );

        expect(created, isFalse);
        expect(viewModel.error, isA<Exception>());
        // The list it already had is untouched.
        expect(viewModel.posts, const [post]);
      },
    );

    test('should re-read when another page says the list is stale', () async {
      final store = MockPostRepository();
      when(() => store.allPosts()).thenAnswer((_) async => const [post]);
      final watch = PostsWatch();
      final viewModel = PostsHomeViewModel(postsDispatcher(store), watch);
      addTearDown(viewModel.dispose);

      await viewModel.load();

      // A page above wrote. This page never remounts, so the watch is the only
      // thing that would ask it to read again.
      watch.markStale();
      await pumpEventQueue();

      verify(() => store.allPosts()).called(2);
      expect(viewModel.posts, const [post]);
    });
  });
}
