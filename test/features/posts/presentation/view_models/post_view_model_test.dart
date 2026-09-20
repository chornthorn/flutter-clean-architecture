import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/core/presentation/action_result.dart';
import 'package:flutter_x/core/presentation/form/app_form_controller.dart';
import 'package:flutter_x/features/posts/domain/entities/post.dart';
import 'package:flutter_x/features/posts/domain/repositories/post_repository.dart';
import 'package:flutter_x/features/posts/infrastructure/repositories/in_memory_post_repository.dart';
import 'package:flutter_x/features/posts/presentation/forms/post_form_field.dart';
import 'package:flutter_x/features/posts/presentation/view_models/post_view_model.dart';
import 'package:mocktail/mocktail.dart';
import 'package:signals/signals_flutter.dart';

import '../../posts_dispatcher_fixture.dart';

class MockPostRepository extends Mock implements PostRepository {}

void main() {
  const post = Post(
    id: 1,
    userId: 1,
    title: 'First post',
    body: 'The body of the first post.',
  );

  group('PostViewModel - Post List features', () {
    test('should report loading until the list arrives', () async {
      final repository = MockPostRepository();
      when(() => repository.allPosts(cancellation: any(named: 'cancellation')))
          .thenAnswer((_) async => const [post]);

      final viewModel = PostViewModel(dispatcher: postsDispatcher(repository));
      addTearDown(viewModel.dispose);

      expect(viewModel.posts.value.isLoading, isTrue);

      await viewModel.load();

      expect(viewModel.posts.value.isLoading, isFalse);
      expect(viewModel.posts.value.value, [post]);
    });

    test('should resolve an empty list to no posts, not an error', () async {
      final repository = MockPostRepository();
      when(() => repository.allPosts(cancellation: any(named: 'cancellation')))
          .thenAnswer((_) async => const []);

      final viewModel = PostViewModel(dispatcher: postsDispatcher(repository));
      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.posts.value.hasError, isFalse);
      expect(viewModel.posts.value.value, isEmpty);
    });

    test('should hold a failure in error instead of throwing', () async {
      final repository = MockPostRepository();
      when(() => repository.allPosts(cancellation: any(named: 'cancellation')))
          .thenAnswer((_) async => throw Exception('offline'));

      final viewModel = PostViewModel(dispatcher: postsDispatcher(repository));
      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.posts.value.hasError, isTrue);
      expect(viewModel.posts.value.value, isNull);
    });

    test('should start the writes settled, so the page does not read them in flight', () {
      final viewModel = PostViewModel(
        dispatcher: postsDispatcher(InMemoryPostRepository()),
      );
      addTearDown(viewModel.dispose);

      expect(viewModel.create.value.isLoading, isFalse);
      expect(viewModel.create.value.hasError, isFalse);
      expect(viewModel.update.value.isLoading, isFalse);
      expect(viewModel.update.value.hasError, isFalse);
      expect(viewModel.delete.value.isLoading, isFalse);
      expect(viewModel.delete.value.hasError, isFalse);
    });

    test(
      'should create from the createFormController values and re-read the list',
      () async {
        final viewModel = PostViewModel(
          dispatcher: postsDispatcher(InMemoryPostRepository()),
        );
        addTearDown(viewModel.dispose);
        await viewModel.load();

        viewModel.prepareCreate();
        viewModel.createFormController.setValues({
          PostFormField.title: 'A new post',
          PostFormField.body: 'A new body',
        });

        final created = await viewModel.createPost();

        expect(created.isSuccess, isTrue);
        expect(viewModel.create.value.hasError, isFalse);
        expect(viewModel.createFormController.hasErrors, isFalse);
        expect(
          viewModel.posts.value.value,
          contains(
            const Post(
              id: 4,
              userId: 1,
              title: 'A new post',
              body: 'A new body',
            ),
          ),
        );
        expect(
          viewModel.createFormController.text(
            const FormFieldKey(PostFormField.title),
          ),
          isEmpty,
        );
      },
    );

    test('should return ActionFailure with field errors and bind to createFormController when validation fails', () async {
      final store = InMemoryPostRepository();
      final viewModel = PostViewModel(dispatcher: postsDispatcher(store));
      addTearDown(viewModel.dispose);

      viewModel.createFormController.setValues({
        PostFormField.title: 'Hey',
        PostFormField.body: 'A body',
      });

      final result = await viewModel.createPost();

      expect(result.isFailure, isTrue);
      expect((result as ActionFailure).fieldErrors, {
        'title': 'Title must be at least 5 characters.',
      });
      expect(
        viewModel.createFormController[const FormFieldKey(PostFormField.title)],
        'Title must be at least 5 characters.',
      );
    });

    test(
      'should keep the failure and answer failure when a create fails',
      () async {
        final store = MockPostRepository();
        when(() => store.allPosts(cancellation: any(named: 'cancellation')))
            .thenAnswer((_) async => const [post]);
        when(
          () => store.createPost(
            userId: any(named: 'userId'),
            title: any(named: 'title'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => throw Exception('offline'));

        final viewModel = PostViewModel(dispatcher: postsDispatcher(store));
        addTearDown(viewModel.dispose);
        await viewModel.load();

        viewModel.createFormController.setValues({
          PostFormField.title: 'A new post',
          PostFormField.body: 'A new body',
        });

        final created = await viewModel.createPost();

        expect(created.isFailure, isTrue);
        expect(viewModel.create.value.hasError, isTrue);
        expect(viewModel.posts.value.value, [post]);
      },
    );

    test('should stay silent when a posts load outlives its view', () async {
      final completer = Completer<List<Post>>();
      final repository = MockPostRepository();
      when(() => repository.allPosts(cancellation: any(named: 'cancellation')))
          .thenAnswer((_) => completer.future);

      final viewModel = PostViewModel(dispatcher: postsDispatcher(repository));
      final pushed = <AsyncState<List<Post>>>[];
      addTearDown(viewModel.posts.subscribe(pushed.add));

      final load = viewModel.load();
      viewModel.dispose();
      completer.complete(const [post]);

      await expectLater(load, completes);

      expect(pushed, isNotEmpty);
      expect(pushed.every((state) => state.isLoading), isTrue);
    });
  });

  group('PostViewModel - Post Detail features', () {
    test('should load the post the query returns', () async {
      final repository = MockPostRepository();
      when(
        () => repository.postById(1, cancellation: any(named: 'cancellation')),
      ).thenAnswer((_) async => post);

      final viewModel = PostViewModel(dispatcher: postsDispatcher(repository));
      addTearDown(viewModel.dispose);

      expect(viewModel.post.value.isLoading, isTrue);

      await viewModel.load(1);

      expect(viewModel.post.value.isLoading, isFalse);
      expect(viewModel.post.value.value, post);
    });

    test('should resolve an unknown id to a null post, not an error', () async {
      final repository = MockPostRepository();
      when(
        () => repository.postById(99, cancellation: any(named: 'cancellation')),
      ).thenAnswer((_) async => null);

      final viewModel = PostViewModel(dispatcher: postsDispatcher(repository));
      addTearDown(viewModel.dispose);

      await viewModel.load(99);

      expect(viewModel.post.value.hasError, isFalse);
      expect(viewModel.post.value.value, isNull);
    });

    test('should hold a failure in error instead of throwing', () async {
      final repository = MockPostRepository();
      when(
        () => repository.postById(1, cancellation: any(named: 'cancellation')),
      ).thenAnswer((_) async => throw Exception('offline'));

      final viewModel = PostViewModel(dispatcher: postsDispatcher(repository));
      addTearDown(viewModel.dispose);

      await viewModel.load(1);

      expect(viewModel.post.value.hasError, isTrue);
      expect(viewModel.post.value.value, isNull);
    });

    test('should start the writes settled, so the page does not read them in flight', () {
      final viewModel = PostViewModel(
        dispatcher: postsDispatcher(InMemoryPostRepository()),
      );
      addTearDown(viewModel.dispose);

      expect(viewModel.update.value.isLoading, isFalse);
      expect(viewModel.update.value.hasError, isFalse);
      expect(viewModel.delete.value.isLoading, isFalse);
      expect(viewModel.delete.value.hasError, isFalse);
    });

    test('should return ActionFailure with field errors and bind to updateFormController when updatePost validation fails', () async {
      final store = InMemoryPostRepository();
      final viewModel = PostViewModel(dispatcher: postsDispatcher(store));
      addTearDown(viewModel.dispose);

      viewModel.updateFormController.setValues({
        PostFormField.title: '   ',
        PostFormField.body: 'A body',
      });

      final result = await viewModel.updatePost(1);

      expect(result.isFailure, isTrue);
      expect((result as ActionFailure).fieldErrors, {
        'title': 'A post needs a title',
      });
      expect(
        viewModel.updateFormController[const FormFieldKey(PostFormField.title)],
        'A post needs a title',
      );
    });

    test('should edit the id it is handed', () async {
      final store = InMemoryPostRepository();
      final viewModel = PostViewModel(dispatcher: postsDispatcher(store));
      addTearDown(viewModel.dispose);

      viewModel.updateFormController.setValues({
        PostFormField.title: 'Edited title',
        PostFormField.body: 'Edited body',
      });

      final result = await viewModel.updatePost(1);
      expect(result.isSuccess, isTrue);
      expect((await store.postById(1))?.title, 'Edited title');
    });

    test('should edit post using viewModel.updateFormController directly after prepareEdit', () async {
      final store = InMemoryPostRepository();
      final viewModel = PostViewModel(dispatcher: postsDispatcher(store));
      addTearDown(viewModel.dispose);

      const currentPost = Post(
        id: 1,
        userId: 1,
        title: 'Old title',
        body: 'Old body',
      );
      viewModel.prepareEdit(currentPost);

      expect(
        viewModel.updateFormController.text(
          const FormFieldKey(PostFormField.title),
        ),
        'Old title',
      );

      viewModel.updateFormController.setValue(
        const FormFieldKey(PostFormField.title),
        'New direct title',
      );

      final result = await viewModel.updatePost(1);
      expect(result.isSuccess, isTrue);
      expect((await store.postById(1))?.title, 'New direct title');
    });

    test(
      'should keep the failure and answer failure when an edit fails',
      () async {
        final store = MockPostRepository();
        when(() => store.postById(1, cancellation: any(named: 'cancellation')))
            .thenAnswer((_) async => post);
        when(
          () => store.updatePost(
            id: 1,
            title: any(named: 'title'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => throw Exception('offline'));

        final viewModel = PostViewModel(dispatcher: postsDispatcher(store));
        addTearDown(viewModel.dispose);
        await viewModel.load(1);

        viewModel.prepareEdit(post);

        final saved = await viewModel.updatePost(1);

        expect(saved.isFailure, isTrue);
        expect(viewModel.update.value.hasError, isTrue);
        expect(viewModel.post.value.value, post);
      },
    );

    test('should delete through the command and settle', () async {
      final store = InMemoryPostRepository();
      final viewModel = PostViewModel(dispatcher: postsDispatcher(store));
      addTearDown(viewModel.dispose);

      final result = await viewModel.deletePost(1);
      expect(result.isSuccess, isTrue);
      expect(await store.postById(1), isNull);
    });

    test(
      'should keep the failure and answer failure when a delete fails',
      () async {
        final store = MockPostRepository();
        when(() => store.deletePost(1))
            .thenAnswer((_) async => throw Exception('offline'));

        final viewModel = PostViewModel(dispatcher: postsDispatcher(store));
        addTearDown(viewModel.dispose);

        final result = await viewModel.deletePost(1);
        expect(result.isFailure, isTrue);
        expect(viewModel.delete.value.hasError, isTrue);
      },
    );
  });
}
