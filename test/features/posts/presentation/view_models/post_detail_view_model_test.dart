import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/posts/infrastructure/repositories/in_memory_post_repository.dart';
import 'package:flutter_x/features/posts/presentation/posts_watch.dart';
import 'package:flutter_x/features/posts/presentation/view_models/post_detail_view_model.dart';
import 'package:mocktail/mocktail.dart';

import '../../domain/entities/post_fixture.dart';
import '../../domain/repositories/mock_post_repository.dart';
import '../../posts_dispatcher_fixture.dart';

void main() {
  group('PostDetailViewModel', () {
    test('should load the post the query returns', () async {
      final repository = MockPostRepository();
      when(() => repository.postById(1)).thenAnswer((_) async => post);

      final viewModel = PostDetailViewModel(
        postsDispatcher(repository),
        PostsWatch(),
      );
      addTearDown(viewModel.dispose);

      await viewModel.load(1);

      expect(viewModel.post, post);
      expect(viewModel.error, isNull);
      expect(viewModel.isLoading, isFalse);
    });

    test('should resolve an unknown id to a null post, not an error', () async {
      final repository = MockPostRepository();
      when(() => repository.postById(999)).thenAnswer((_) async => null);

      final viewModel = PostDetailViewModel(
        postsDispatcher(repository),
        PostsWatch(),
      );
      addTearDown(viewModel.dispose);

      await viewModel.load(999);

      expect(viewModel.post, isNull);
      expect(viewModel.error, isNull);
      expect(viewModel.isLoading, isFalse);
    });

    test('should hold a failure in error instead of throwing', () async {
      final repository = MockPostRepository();
      when(
        () => repository.postById(1),
      ).thenAnswer((_) async => throw Exception('offline'));

      final viewModel = PostDetailViewModel(
        postsDispatcher(repository),
        PostsWatch(),
      );
      addTearDown(viewModel.dispose);

      await expectLater(viewModel.load(1), completes);

      expect(viewModel.error, isA<Exception>());
      expect(viewModel.post, isNull);
    });

    test('should edit through the command and re-read the post', () async {
      // A real store: the new title shows up only if the command wrote it and the
      // reload read it back.
      final store = InMemoryPostRepository();
      final viewModel = PostDetailViewModel(
        postsDispatcher(store),
        PostsWatch(),
      );
      addTearDown(viewModel.dispose);
      await viewModel.load(1);

      final saved = await viewModel.updatePost(
        title: 'Edited title',
        body: 'Edited body',
      );

      expect(saved, isTrue);
      expect(viewModel.error, isNull);
      expect(viewModel.post?.title, 'Edited title');
      expect(viewModel.post?.body, 'Edited body');
      // The author is not the editor's to change.
      expect(viewModel.post?.userId, 1);
    });

    test(
      'should keep the failure and answer false when an edit fails',
      () async {
        final store = MockPostRepository();
        when(() => store.postById(1)).thenAnswer((_) async => post);
        when(
          () => store.updatePost(
            id: any(named: 'id'),
            title: any(named: 'title'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => throw Exception('offline'));

        final viewModel = PostDetailViewModel(
          postsDispatcher(store),
          PostsWatch(),
        );
        addTearDown(viewModel.dispose);
        await viewModel.load(1);

        final saved = await viewModel.updatePost(
          title: 'Edited title',
          body: 'Edited body',
        );

        expect(saved, isFalse);
        expect(viewModel.error, isA<Exception>());
        // What was on screen is untouched.
        expect(viewModel.post, post);
      },
    );

    test('should delete through the command and answer true', () async {
      final store = InMemoryPostRepository();
      final viewModel = PostDetailViewModel(
        postsDispatcher(store),
        PostsWatch(),
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
        when(() => store.postById(1)).thenAnswer((_) async => post);
        when(
          () => store.deletePost(any()),
        ).thenAnswer((_) async => throw Exception('offline'));

        final viewModel = PostDetailViewModel(
          postsDispatcher(store),
          PostsWatch(),
        );
        addTearDown(viewModel.dispose);
        await viewModel.load(1);

        expect(await viewModel.deletePost(), isFalse);
        expect(viewModel.error, isA<Exception>());
        expect(viewModel.post, post);
      },
    );

    test('should tell the feature its list is stale after an edit', () async {
      final store = InMemoryPostRepository();
      var stale = 0;
      final watch = PostsWatch()..addListener(() => stale++);
      final viewModel = PostDetailViewModel(postsDispatcher(store), watch);
      addTearDown(viewModel.dispose);
      await viewModel.load(1);

      await viewModel.updatePost(title: 'Edited title', body: 'Edited body');

      expect(stale, 1);
    });

    test('should tell the feature its list is stale after a delete', () async {
      final store = InMemoryPostRepository();
      var stale = 0;
      final watch = PostsWatch()..addListener(() => stale++);
      final viewModel = PostDetailViewModel(postsDispatcher(store), watch);
      addTearDown(viewModel.dispose);
      await viewModel.load(1);

      await viewModel.deletePost();

      expect(stale, 1);
    });

    test('should say nothing when an edit fails', () async {
      final store = MockPostRepository();
      when(() => store.postById(1)).thenAnswer((_) async => post);
      when(
        () => store.updatePost(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => throw Exception('offline'));
      var stale = 0;
      final watch = PostsWatch()..addListener(() => stale++);
      final viewModel = PostDetailViewModel(postsDispatcher(store), watch);
      addTearDown(viewModel.dispose);
      await viewModel.load(1);

      await viewModel.updatePost(title: 'Edited title', body: 'Edited body');

      // Nothing was written, so nothing below needs re-reading.
      expect(stale, 0);
    });
  });
}
