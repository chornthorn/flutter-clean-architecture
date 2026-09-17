import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/core/presentation/action_result.dart';
import 'package:flutter_x/core/presentation/form/form_field_key.dart';
import 'package:flutter_x/features/posts/domain/entities/post.dart';
import 'package:flutter_x/features/posts/infrastructure/repositories/in_memory_post_repository.dart';
import 'package:flutter_x/features/posts/presentation/forms/post_form_field.dart';
import 'package:flutter_x/features/posts/presentation/view_models/posts_home_view_model.dart';
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

  group('PostsHomeViewModel', () {
    test('should report loading until the list arrives', () async {
      final viewModel = PostsHomeViewModel(
        postsDispatcher(InMemoryPostRepository()),
      );
      addTearDown(viewModel.dispose);

      expect(viewModel.posts.value.isLoading, isTrue);

      await viewModel.load();

      expect(viewModel.posts.value.isLoading, isFalse);
      expect(viewModel.posts.value.value, isNotEmpty);
    });

    test(
      'should start the create settled, so the page does not read it in flight',
      () {
        final viewModel = PostsHomeViewModel(
          postsDispatcher(InMemoryPostRepository()),
        );
        addTearDown(viewModel.dispose);

        expect(viewModel.create.value.isLoading, isFalse);
        expect(viewModel.create.value.hasError, isFalse);
      },
    );

    test('should create through the command and re-read the list', () async {
      final viewModel = PostsHomeViewModel(
        postsDispatcher(InMemoryPostRepository()),
      );
      addTearDown(viewModel.dispose);
      await viewModel.load();

      final created = await viewModel.createPost(
        title: 'A new post',
        body: 'A new body',
      );

      expect(created.isSuccess, isTrue);
      expect(viewModel.create.value.hasError, isFalse);
      expect(viewModel.form.hasErrors, isFalse);
      expect(
        viewModel.posts.value.value,
        contains(
          const Post(id: 4, userId: 1, title: 'A new post', body: 'A new body'),
        ),
      );
    });

    test(
      'should create post using values from viewModel.form directly',
      () async {
        final viewModel = PostsHomeViewModel(
          postsDispatcher(InMemoryPostRepository()),
        );
        addTearDown(viewModel.dispose);
        await viewModel.load();

        viewModel.prepareCreate();
        viewModel.form.setValues({
          PostFormField.title: 'Form post title',
          PostFormField.body: 'Form post body',
        });

        final created = await viewModel.createPost();

        expect(created.isSuccess, isTrue);
        expect(
          viewModel.posts.value.value,
          contains(
            const Post(
              id: 4,
              userId: 1,
              title: 'Form post title',
              body: 'Form post body',
            ),
          ),
        );
        // Form was cleared after successful submit
        expect(
          viewModel.form.text(const FormFieldKey(PostFormField.title)),
          isEmpty,
        );
      },
    );

    test('should return ActionFailure with field errors and bind to form when validation fails', () async {
      final store = InMemoryPostRepository();
      final viewModel = PostsHomeViewModel(postsDispatcher(store));
      addTearDown(viewModel.dispose);

      final result = await viewModel.createPost(title: 'Hey', body: 'A body');

      expect(result.isFailure, isTrue);
      expect((result as ActionFailure).fieldErrors, {
        'title': 'Title must be at least 5 characters.',
      });
      // Verified: form controller owned by viewModel binds errors automatically!
      expect(
        viewModel.form[const FormFieldKey(PostFormField.title)],
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

        final viewModel = PostsHomeViewModel(postsDispatcher(store));
        addTearDown(viewModel.dispose);
        await viewModel.load();

        final created = await viewModel.createPost(
          title: 'A new post',
          body: 'A new body',
        );

        expect(created.isFailure, isTrue);
        expect(viewModel.create.value.hasError, isTrue);
        expect(viewModel.posts.value.value, [post]);
      },
    );

    test('should stay silent when a load outlives its view', () async {
      final repository = MockPostRepository();
      when(() => repository.allPosts(cancellation: any(named: 'cancellation')))
          .thenAnswer(
            (_) => Future<List<Post>>.delayed(
              const Duration(milliseconds: 50),
              () => const [post],
            ),
          );

      final viewModel = PostsHomeViewModel(postsDispatcher(repository));
      final load = viewModel.load();
      viewModel.dispose();
      await load;

      expect(viewModel.posts.value.value, isNull);
    });
  });
}
