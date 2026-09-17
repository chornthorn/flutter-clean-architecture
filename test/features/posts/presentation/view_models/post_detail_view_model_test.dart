import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/core/presentation/action_result.dart';
import 'package:flutter_x/core/presentation/form/form_field_key.dart';
import 'package:flutter_x/features/posts/domain/entities/post.dart';
import 'package:flutter_x/features/posts/infrastructure/repositories/in_memory_post_repository.dart';
import 'package:flutter_x/features/posts/presentation/forms/post_form_field.dart';
import 'package:flutter_x/features/posts/presentation/view_models/post_detail_view_model.dart';
import 'package:mocktail/mocktail.dart';

import '../../domain/repositories/mock_post_repository.dart';
import '../../posts_dispatcher_fixture.dart';

void main() {
  const post = Post(
    id: 1,
    userId: 1,
    title: 'First post',
    body: 'The first post in the local fixture.',
  );

  group('PostDetailViewModel', () {
    test('should load the post the query returns', () async {
      final repository = MockPostRepository();
      when(
        () => repository.postById(1, cancellation: any(named: 'cancellation')),
      ).thenAnswer((_) async => post);

      final viewModel = PostDetailViewModel(postsDispatcher(repository));
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

      final viewModel = PostDetailViewModel(postsDispatcher(repository));
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

      final viewModel = PostDetailViewModel(postsDispatcher(repository));
      addTearDown(viewModel.dispose);

      await viewModel.load(1);

      expect(viewModel.post.value.hasError, isTrue);
      expect(viewModel.post.value.value, isNull);
    });

    test('should start the writes settled, so the page does not read them in flight', () {
      final viewModel = PostDetailViewModel(
        postsDispatcher(InMemoryPostRepository()),
      );
      addTearDown(viewModel.dispose);

      expect(viewModel.update.value.isLoading, isFalse);
      expect(viewModel.update.value.hasError, isFalse);
      expect(viewModel.delete.value.isLoading, isFalse);
      expect(viewModel.delete.value.hasError, isFalse);
    });

    test('should return ActionFailure with field errors and bind to form when updatePost validation fails', () async {
      final store = InMemoryPostRepository();
      final viewModel = PostDetailViewModel(postsDispatcher(store));
      addTearDown(viewModel.dispose);

      final result = await viewModel.updatePost(
        1,
        title: '   ',
        body: 'A body',
      );

      expect(result.isFailure, isTrue);
      expect((result as ActionFailure).fieldErrors, {
        'title': 'A post needs a title',
      });
      expect(
        viewModel.form[const FormFieldKey(PostFormField.title)],
        'A post needs a title',
      );
    });

    test(
      'should edit the id it is handed, with nothing on screen yet',
      () async {
        final store = InMemoryPostRepository();
        final viewModel = PostDetailViewModel(postsDispatcher(store));
        addTearDown(viewModel.dispose);

        final result = await viewModel.updatePost(
          1,
          title: 'Edited title',
          body: 'Edited body',
        );
        expect(result.isSuccess, isTrue);
        expect((await store.postById(1))?.title, 'Edited title');
      },
    );

    test(
      'should edit post using viewModel.form directly after prepareEdit',
      () async {
        final store = InMemoryPostRepository();
        final viewModel = PostDetailViewModel(postsDispatcher(store));
        addTearDown(viewModel.dispose);

        const currentPost = Post(
          id: 1,
          userId: 1,
          title: 'Old title',
          body: 'Old body',
        );
        viewModel.prepareEdit(currentPost);

        expect(
          viewModel.form.text(const FormFieldKey(PostFormField.title)),
          'Old title',
        );

        // User edits title
        viewModel.form.setValue(
          const FormFieldKey(PostFormField.title),
          'New direct title',
        );

        final result = await viewModel.updatePost(1);
        expect(result.isSuccess, isTrue);
        expect((await store.postById(1))?.title, 'New direct title');
      },
    );

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

        final viewModel = PostDetailViewModel(postsDispatcher(store));
        addTearDown(viewModel.dispose);
        await viewModel.load(1);

        final saved = await viewModel.updatePost(
          1,
          title: 'Edited title',
          body: 'Edited body',
        );

        expect(saved.isFailure, isTrue);
        expect(viewModel.update.value.hasError, isTrue);
        expect(viewModel.post.value.value, post);
      },
    );

    test('should delete through the command and settle', () async {
      final store = InMemoryPostRepository();
      final viewModel = PostDetailViewModel(postsDispatcher(store));
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

        final viewModel = PostDetailViewModel(postsDispatcher(store));
        addTearDown(viewModel.dispose);

        final deleted = await viewModel.deletePost(1);

        expect(deleted.isFailure, isTrue);
        expect(viewModel.delete.value.hasError, isTrue);
      },
    );

    test('should stay silent when a load outlives its view', () async {
      final repository = MockPostRepository();
      when(
        () => repository.postById(1, cancellation: any(named: 'cancellation')),
      ).thenAnswer(
        (_) =>
            Future<Post?>.delayed(const Duration(milliseconds: 50), () => post),
      );

      final viewModel = PostDetailViewModel(postsDispatcher(repository));
      final load = viewModel.load(1);
      viewModel.dispose();
      await load;

      expect(viewModel.post.value.value, isNull);
    });
  });
}
