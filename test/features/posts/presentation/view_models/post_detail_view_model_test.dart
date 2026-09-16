import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/core/async/cancellation.dart';
import 'package:flutter_x/features/posts/domain/entities/post.dart';
import 'package:flutter_x/features/posts/infrastructure/repositories/in_memory_post_repository.dart';
import 'package:flutter_x/features/posts/presentation/posts_revision.dart';
import 'package:flutter_x/features/posts/presentation/view_models/post_detail_view_model.dart';
import 'package:mocktail/mocktail.dart';
import 'package:signals/signals_flutter.dart';

import '../../domain/entities/post_fixture.dart';
import '../../domain/repositories/mock_post_repository.dart';
import '../../posts_dispatcher_fixture.dart';

void main() {
  group('PostDetailViewModel', () {
    test('should load the post the query returns', () async {
      final repository = MockPostRepository();
      when(
        () => repository.postById(1, cancellation: any(named: 'cancellation')),
      ).thenAnswer((_) async => post);

      final viewModel = PostDetailViewModel(
        postsDispatcher(repository),
        PostsRevision(),
      );
      addTearDown(viewModel.dispose);

      await viewModel.load(1);

      expect(viewModel.post.value, AsyncState<Post?>.data(post));
      expect(viewModel.post.value.hasError, isFalse);
      expect(viewModel.post.value.isLoading, isFalse);
    });

    test('should resolve an unknown id to a null post, not an error', () async {
      final repository = MockPostRepository();
      when(
        () =>
            repository.postById(999, cancellation: any(named: 'cancellation')),
      ).thenAnswer((_) async => null);

      final viewModel = PostDetailViewModel(
        postsDispatcher(repository),
        PostsRevision(),
      );
      addTearDown(viewModel.dispose);

      await viewModel.load(999);

      // A value that is null is a value: the page tells a missing post from a
      // failed read by the state, not by the error.
      expect(viewModel.post.value, AsyncState<Post?>.data(null));
      expect(viewModel.post.value.hasError, isFalse);
      expect(viewModel.post.value.isLoading, isFalse);
    });

    test('should hold a failure in error instead of throwing', () async {
      final repository = MockPostRepository();
      when(
        () => repository.postById(1, cancellation: any(named: 'cancellation')),
      ).thenAnswer((_) async => throw Exception('offline'));

      final viewModel = PostDetailViewModel(
        postsDispatcher(repository),
        PostsRevision(),
      );
      addTearDown(viewModel.dispose);

      await expectLater(viewModel.load(1), completes);

      expect(viewModel.post.value.hasError, isTrue);
      expect(viewModel.post.value.hasValue, isFalse);
      expect(viewModel.post.value.isLoading, isFalse);
    });

    test('should start both writes settled, so neither reads as in flight', () {
      final viewModel = PostDetailViewModel(
        postsDispatcher(MockPostRepository()),
        PostsRevision(),
      );
      addTearDown(viewModel.dispose);

      expect(viewModel.update.value.isLoading, isFalse);
      expect(viewModel.delete.value.isLoading, isFalse);
      // The read is the one that starts in flight, which is what the page
      // renders first.
      expect(viewModel.post.value.isLoading, isTrue);
    });

    test('should edit through the command and re-read the post', () async {
      // A real store: the new title shows up only if the command wrote it and the
      // reload read it back.
      final store = InMemoryPostRepository();
      final viewModel = PostDetailViewModel(
        postsDispatcher(store),
        PostsRevision(),
      );
      addTearDown(viewModel.dispose);
      await viewModel.load(1);

      final saved = await viewModel.updatePost(
        title: 'Edited title',
        body: 'Edited body',
      );

      expect(saved, isTrue);
      expect(viewModel.update.value.hasError, isFalse);
      expect(viewModel.post.value.value?.title, 'Edited title');
      expect(viewModel.post.value.value?.body, 'Edited body');
      // The author is not the editor's to change.
      expect(viewModel.post.value.value?.userId, 1);
    });

    test(
      'should keep the failure and answer false when an edit fails',
      () async {
        final store = MockPostRepository();
        when(
          () => store.postById(1, cancellation: any(named: 'cancellation')),
        ).thenAnswer((_) async => post);
        when(
          () => store.updatePost(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => throw Exception('offline'));

        final viewModel = PostDetailViewModel(
          postsDispatcher(store),
          PostsRevision(),
        );
        addTearDown(viewModel.dispose);
        await viewModel.load(1);

        final saved = await viewModel.updatePost(
          title: 'Edited title',
          body: 'Edited body',
        );

        expect(saved, isFalse);
        expect(viewModel.update.value.hasError, isTrue);
        // What was on screen is untouched — and the read it came from is not the
        // use case that failed, so its state is untouched too.
        expect(viewModel.post.value.value, post);
        expect(viewModel.post.value.hasError, isFalse);
      },
    );

    test('should delete through the command and answer true', () async {
      final store = InMemoryPostRepository();
      final viewModel = PostDetailViewModel(
        postsDispatcher(store),
        PostsRevision(),
      );
      addTearDown(viewModel.dispose);
      await viewModel.load(1);

      expect(await viewModel.deletePost(), isTrue);
      expect(await store.postById(1), isNull);
    });

    test(
      'should keep the failure and answer false when a delete fails',
      () async {
        final store = MockPostRepository();
        when(
          () => store.postById(1, cancellation: any(named: 'cancellation')),
        ).thenAnswer((_) async => post);
        when(
          () => store.deletePost(any()),
        ).thenAnswer((_) async => throw Exception('offline'));

        final viewModel = PostDetailViewModel(
          postsDispatcher(store),
          PostsRevision(),
        );
        addTearDown(viewModel.dispose);
        await viewModel.load(1);

        expect(await viewModel.deletePost(), isFalse);
        expect(viewModel.delete.value.hasError, isTrue);
        expect(viewModel.post.value.value, post);
        expect(viewModel.post.value.hasError, isFalse);
      },
    );

    test(
      'should report a delete in flight over its own use case only',
      () async {
        final store = MockPostRepository();
        when(
          () => store.postById(1, cancellation: any(named: 'cancellation')),
        ).thenAnswer((_) async => post);
        final inFlight = Completer<void>();
        when(() => store.deletePost(any())).thenAnswer((_) => inFlight.future);

        final viewModel = PostDetailViewModel(
          postsDispatcher(store),
          PostsRevision(),
        );
        addTearDown(viewModel.dispose);
        await viewModel.load(1);

        final deleting = viewModel.deletePost();

        // Which write is on the wire is read off the use case it belongs to, and
        // no other state reports it.
        expect(viewModel.delete.value.isLoading, isTrue);
        expect(viewModel.update.value.isLoading, isFalse);
        expect(viewModel.post.value.isLoading, isFalse);

        inFlight.complete();

        expect(await deleting, isTrue);
        expect(viewModel.delete.value.isLoading, isFalse);
        expect(viewModel.delete.value.hasError, isFalse);
      },
    );

    test('should tell the feature its list is stale after an edit', () async {
      final store = InMemoryPostRepository();
      final revision = PostsRevision();
      final viewModel = PostDetailViewModel(postsDispatcher(store), revision);
      addTearDown(viewModel.dispose);
      await viewModel.load(1);
      final markedAt = revision.revision.peek();

      await viewModel.updatePost(title: 'Edited title', body: 'Edited body');

      // One bump: the list below is now wrong about this post.
      expect(revision.revision.peek() - markedAt, 1);
    });

    test('should tell the feature its list is stale after a delete', () async {
      final store = InMemoryPostRepository();
      final revision = PostsRevision();
      final viewModel = PostDetailViewModel(postsDispatcher(store), revision);
      addTearDown(viewModel.dispose);
      await viewModel.load(1);
      final markedAt = revision.revision.peek();

      await viewModel.deletePost();

      expect(revision.revision.peek() - markedAt, 1);
    });

    test('should say nothing when an edit fails', () async {
      final store = MockPostRepository();
      when(
        () => store.postById(1, cancellation: any(named: 'cancellation')),
      ).thenAnswer((_) async => post);
      when(
        () => store.updatePost(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => throw Exception('offline'));
      final revision = PostsRevision();
      final viewModel = PostDetailViewModel(postsDispatcher(store), revision);
      addTearDown(viewModel.dispose);
      await viewModel.load(1);
      final markedAt = revision.revision.peek();

      await viewModel.updatePost(title: 'Edited title', body: 'Edited body');

      // Nothing was written, so nothing below needs re-reading.
      expect(revision.revision.peek(), markedAt);
    });

    test('should let go of a read its page walked away from', () async {
      final repository = MockPostRepository();
      Cancellation? walkedAway;
      when(
        () => repository.postById(1, cancellation: any(named: 'cancellation')),
      ).thenAnswer((invocation) {
        walkedAway = invocation.namedArguments[#cancellation] as Cancellation?;
        // Stands in for the transport: the read answers only once the page has
        // gone, and it answers with a dropped request rather than with data.
        return walkedAway!.then((_) => throw Exception('dropped'));
      });

      final viewModel = PostDetailViewModel(
        postsDispatcher(repository),
        PostsRevision(),
      );
      // Everything the read pushed, so this can be checked after the signals it
      // pushed to have been disposed with the page.
      final pushed = <AsyncState<Post?>>[];
      addTearDown(viewModel.post.subscribe(pushed.add));

      final load = viewModel.load(1);
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
