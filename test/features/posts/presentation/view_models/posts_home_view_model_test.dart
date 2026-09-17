import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/core/async/cancellation.dart';
import 'package:flutter_x/core/presentation/action_result.dart';
import 'package:flutter_x/features/posts/domain/entities/post.dart';
import 'package:flutter_x/features/posts/infrastructure/repositories/in_memory_post_repository.dart';
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

      final viewModel = PostsHomeViewModel(postsDispatcher(repository));
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

      final viewModel = PostsHomeViewModel(postsDispatcher(repository));
      addTearDown(viewModel.dispose);

      await expectLater(viewModel.load(), completes);

      expect(viewModel.posts.value.hasError, isTrue);
      expect(viewModel.posts.value.hasValue, isFalse);
    });

    test(
      'should start the create settled, so it does not read as in flight',
      () {
        final viewModel = PostsHomeViewModel(
          postsDispatcher(MockPostRepository()),
        );
        addTearDown(viewModel.dispose);

        expect(viewModel.create.value.isLoading, isFalse);
      },
    );

    test('should create through the command and re-read the list', () async {
      // A real store: the post shows up only if the command wrote it and the reload read it back.
      final store = InMemoryPostRepository();
      final viewModel = PostsHomeViewModel(postsDispatcher(store));
      addTearDown(viewModel.dispose);
      await viewModel.load();

      final created = await viewModel.createPost(
        title: 'A new post',
        body: 'A new body',
      );

      expect(created.isSuccess, isTrue);
      expect(viewModel.create.value.hasError, isFalse);
      expect(
        viewModel.posts.value.value,
        contains(
          const Post(id: 4, userId: 1, title: 'A new post', body: 'A new body'),
        ),
      );
    });

    test(
      'should return ActionFailure with field errors when createPost validation fails',
      () async {
        final store = InMemoryPostRepository();
        final viewModel = PostsHomeViewModel(postsDispatcher(store));
        addTearDown(viewModel.dispose);

        final result = await viewModel.createPost(
          title: 'Hey',
          body: 'A body',
        );

        expect(result.isFailure, isTrue);
        expect(
          (result as ActionFailure).fieldErrors,
          {'title': 'Title must be at least 5 characters.'},
        );
      },
    );

    test(
      'should keep the failure and answer failure when a create fails',
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

        final viewModel = PostsHomeViewModel(postsDispatcher(store));
        addTearDown(viewModel.dispose);
        await viewModel.load();

        final created = await viewModel.createPost(
          title: 'A new post',
          body: 'A new body',
        );

        expect(created.isFailure, isTrue);
        expect(viewModel.create.value.hasError, isTrue);
        // The list is untouched, and so is the read's state: another use case failed.
        expect(viewModel.posts.value.value, const [post]);
        expect(viewModel.posts.value.hasError, isFalse);
      },
    );

    test('should let go of a read its page walked away from', () async {
      final repository = MockPostRepository();
      Cancellation? walkedAway;
      when(
        () => repository.allPosts(cancellation: any(named: 'cancellation')),
      ).thenAnswer((invocation) {
        walkedAway = invocation.namedArguments[#cancellation] as Cancellation?;
        // The read answers only once the page has gone, and with a dropped request.
        return walkedAway!.then((_) => throw Exception('dropped'));
      });

      final viewModel = PostsHomeViewModel(postsDispatcher(repository));
      // Everything the read pushed, checked after its signals died with the page.
      final pushed = <AsyncState<List<Post>>>[];
      addTearDown(viewModel.posts.subscribe(pushed.add));

      final load = viewModel.load();
      expect(walkedAway, isNotNull);

      // Navigating away is the provider disposing this view model.
      viewModel.dispose();
      await load;

      // A dropped read is not a failure: it only ever pushed the loading state it started in.
      expect(pushed, isNotEmpty);
      expect(pushed.every((state) => state.isLoading), isTrue);
    });
  });
}
