import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/core/presentation/action_result.dart';
import 'package:flutter_x/core/presentation/form/form_field_key.dart';
import 'package:flutter_x/features/posts/infrastructure/repositories/in_memory_post_repository.dart';
import 'package:flutter_x/features/posts/presentation/view_models/post_detail_view_model.dart';
import 'package:flutter_x/features/posts/presentation/widgets/post_form_dialog.dart';
import 'package:mocktail/mocktail.dart';

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

      final viewModel = PostDetailViewModel(postsDispatcher(repository));
      addTearDown(viewModel.dispose);

      final load = viewModel.load(1);
      expect(viewModel.post.value.isLoading, isTrue);

      await load;
      expect(viewModel.post.value.isLoading, isFalse);
      expect(viewModel.post.value.value, post);
    });

    test('should resolve an unknown id to a null post, not an error', () async {
      final repository = MockPostRepository();
      when(
        () => repository.postById(
          999,
          cancellation: any(named: 'cancellation'),
        ),
      ).thenAnswer((_) async => null);

      final viewModel = PostDetailViewModel(postsDispatcher(repository));
      addTearDown(viewModel.dispose);

      await viewModel.load(999);

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
    });

    test(
      'should start the writes settled, so the page does not read them in flight',
      () {
        final viewModel = PostDetailViewModel(
          postsDispatcher(MockPostRepository()),
        );
        addTearDown(viewModel.dispose);

        expect(viewModel.update.value.isLoading, isFalse);
        expect(viewModel.delete.value.isLoading, isFalse);
        // The read is the one that starts in flight — what the page renders first.
        expect(viewModel.post.value.isLoading, isTrue);
      },
    );

    test('should edit through the command and re-read the post', () async {
      // A real store: the title changes only if the command wrote it and the reload read it back.
      final store = InMemoryPostRepository();
      final viewModel = PostDetailViewModel(postsDispatcher(store));
      addTearDown(viewModel.dispose);
      await viewModel.load(1);

      final saved = await viewModel.updatePost(
        1,
        title: 'Edited title',
        body: 'Edited body',
      );

      expect(saved.isSuccess, isTrue);
      expect(viewModel.update.value.hasError, isFalse);
      expect(viewModel.form.hasErrors, isFalse);
      expect(viewModel.post.value.value?.title, 'Edited title');
      expect(viewModel.post.value.value?.body, 'Edited body');
      // The author is not the editor's to change.
      expect(viewModel.post.value.value?.userId, 1);
    });

    test(
      'should return ActionFailure with field errors and bind to form when updatePost validation fails',
      () async {
        final store = InMemoryPostRepository();
        final viewModel = PostDetailViewModel(postsDispatcher(store));
        addTearDown(viewModel.dispose);

        final result = await viewModel.updatePost(1, title: '', body: 'A body');

        expect(result.isFailure, isTrue);
        expect((result as ActionFailure).fieldErrors, {
          'title': 'A post needs a title',
        });
        expect(
          viewModel.form[const FormFieldKey(PostFormField.title)],
          'A post needs a title',
        );
      },
    );

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
      'should keep the failure and answer failure when an edit fails',
      () async {
        final store = MockPostRepository();
        when(
          () => store.postById(1, cancellation: any(named: 'cancellation')),
        ).thenAnswer((_) async => post);
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
        expect(viewModel.post.value.value?.title, post.title);
      },
    );

    test('should delete through the command and close', () async {
      final store = InMemoryPostRepository();
      final viewModel = PostDetailViewModel(postsDispatcher(store));
      addTearDown(viewModel.dispose);
      await viewModel.load(1);

      final removed = await viewModel.deletePost(1);

      expect(removed.isSuccess, isTrue);
      expect(viewModel.delete.value.hasError, isFalse);
      expect(await store.postById(1), isNull);
    });

    test(
      'should keep the failure and answer failure when a delete fails',
      () async {
        final store = MockPostRepository();
        when(
          () => store.postById(1, cancellation: any(named: 'cancellation')),
        ).thenAnswer((_) async => post);
        when(
          () => store.deletePost(1),
        ).thenAnswer((_) async => throw Exception('offline'));

        final viewModel = PostDetailViewModel(postsDispatcher(store));
        addTearDown(viewModel.dispose);
        await viewModel.load(1);

        final removed = await viewModel.deletePost(1);

        expect(removed.isFailure, isTrue);
        expect(viewModel.delete.value.hasError, isTrue);
      },
    );

    test('should stay silent when a load outlives its view', () async {
      final repository = MockPostRepository();
      when(
        () => repository.postById(1, cancellation: any(named: 'cancellation')),
      ).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return post;
      });

      final viewModel = PostDetailViewModel(postsDispatcher(repository));
      final load = viewModel.load(1);
      viewModel.dispose();

      await load;

      expect(viewModel.post.value.isLoading, isTrue);
    });
  });
}
