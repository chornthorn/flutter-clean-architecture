import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/core/async/cancellation.dart';
import 'package:flutter_x/features/posts/domain/entities/post.dart';
import 'package:flutter_x/features/posts/infrastructure/repositories/in_memory_post_repository.dart';
import 'package:flutter_x/features/posts/presentation/posts_revision.dart';
import 'package:flutter_x/features/posts/presentation/view_models/posts_home_view_model.dart';
import 'package:mocktail/mocktail.dart';
import 'package:signals/signals_flutter.dart';

import '../../domain/entities/post_fixture.dart';
import '../../domain/repositories/mock_post_repository.dart';
import '../../posts_dispatcher_fixture.dart';

void main() {
  group('PostsHomeViewModel', () {
    test('should report loading until the list arrives', () async {
      final repository = MockPostRepository();
      when(
        () => repository.allPosts(cancellation: any(named: 'cancellation')),
      ).thenAnswer((_) async => const [post]);

      final viewModel = PostsHomeViewModel(
        postsDispatcher(repository),
        PostsRevision(),
      );
      addTearDown(viewModel.dispose);

      final load = viewModel.load();
      expect(viewModel.posts.value.isLoading, isTrue);
      expect(viewModel.posts.value.hasValue, isFalse);

      await load;
      expect(viewModel.posts.value.isLoading, isFalse);
      expect(viewModel.posts.value, AsyncState<List<Post>>.data(const [post]));
    });

    test('should hold a failure in error instead of throwing', () async {
      final repository = MockPostRepository();
      when(
        () => repository.allPosts(cancellation: any(named: 'cancellation')),
      ).thenAnswer((_) async => throw Exception('offline'));

      final viewModel = PostsHomeViewModel(
        postsDispatcher(repository),
        PostsRevision(),
      );
      addTearDown(viewModel.dispose);

      await expectLater(viewModel.load(), completes);

      expect(viewModel.posts.value.hasError, isTrue);
      expect(viewModel.posts.value.hasValue, isFalse);
    });

    test('should start the create settled, so it does not read as in flight', () {
      final viewModel = PostsHomeViewModel(
        postsDispatcher(MockPostRepository()),
        PostsRevision(),
      );
      addTearDown(viewModel.dispose);

      expect(viewModel.create.value.isLoading, isFalse);
    });

    test('should create through the command and re-read the list', () async {
      // A real store: the post shows up in the list only if the command wrote it
      // and the reload read it back.
      final store = InMemoryPostRepository();
      final viewModel = PostsHomeViewModel(
        postsDispatcher(store),
        PostsRevision(),
      );
      addTearDown(viewModel.dispose);
      await viewModel.load();

      final created = await viewModel.createPost(
        title: 'A new post',
        body: 'A new body',
      );

      expect(created, isTrue);
      expect(viewModel.create.value.hasError, isFalse);
      expect(
        viewModel.posts.value.value,
        contains(
          const Post(id: 4, userId: 1, title: 'A new post', body: 'A new body'),
        ),
      );
    });

    test(
      'should keep the failure and answer false when a create fails',
      () async {
        final store = MockPostRepository();
        when(
          () => store.allPosts(cancellation: any(named: 'cancellation')),
        ).thenAnswer((_) async => const [post]);
        when(
          () => store.createPost(
            userId: any(named: 'userId'),
            title: any(named: 'title'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => throw Exception('offline'));

        final viewModel = PostsHomeViewModel(
          postsDispatcher(store),
          PostsRevision(),
        );
        addTearDown(viewModel.dispose);
        await viewModel.load();

        final created = await viewModel.createPost(
          title: 'A new post',
          body: 'A new body',
        );

        expect(created, isFalse);
        expect(viewModel.create.value.hasError, isTrue);
        // The list it already had is untouched — and so is the read's own state,
        // because the write is not the use case that failed.
        expect(viewModel.posts.value.value, const [post]);
        expect(viewModel.posts.value.hasError, isFalse);
      },
    );

    test('should re-read when another page says the list is stale', () async {
      final store = MockPostRepository();
      when(
        () => store.allPosts(cancellation: any(named: 'cancellation')),
      ).thenAnswer((_) async => const [post]);
      final revision = PostsRevision();
      final viewModel = PostsHomeViewModel(postsDispatcher(store), revision);
      addTearDown(viewModel.dispose);

      await viewModel.load();

      // A page above wrote. This page never remounts, so the revision is the
      // only thing that would ask it to read again.
      revision.markStale();
      await pumpEventQueue();

      verify(
        () => store.allPosts(cancellation: any(named: 'cancellation')),
      ).called(2);
      expect(viewModel.posts.value.value, const [post]);
    });

    test('should let go of a read its page walked away from', () async {
      final repository = MockPostRepository();
      Cancellation? walkedAway;
      when(
        () => repository.allPosts(cancellation: any(named: 'cancellation')),
      ).thenAnswer((invocation) {
        walkedAway = invocation.namedArguments[#cancellation] as Cancellation?;
        // Stands in for the transport: the read answers only once the page has
        // gone, and it answers with a dropped request rather than with data.
        return walkedAway!.then((_) => throw Exception('dropped'));
      });

      final viewModel = PostsHomeViewModel(
        postsDispatcher(repository),
        PostsRevision(),
      );
      // Everything the read pushed, so this can be checked after the signals it
      // pushed to have been disposed with the page.
      final pushed = <AsyncState<List<Post>>>[];
      addTearDown(viewModel.posts.subscribe(pushed.add));

      final load = viewModel.load();
      expect(walkedAway, isNotNull);

      // Navigating away is the provider disposing this view model.
      viewModel.dispose();
      await load;

      // A dropped read is not a failure, and there is nobody left to tell: the
      // only state it ever pushed is the loading state it started in.
      expect(pushed, isNotEmpty);
      expect(pushed.every((state) => state.isLoading), isTrue);
    });
  });
}
