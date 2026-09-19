import 'package:cqrs/cqrs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/posts/domain/entities/post.dart';
import 'package:flutter_x/features/posts/domain/usecases/create_post_command.dart';
import 'package:flutter_x/features/posts/domain/usecases/get_posts_query.dart';
import 'package:flutter_x/features/posts/infrastructure/repositories/in_memory_post_repository.dart';
import 'package:flutter_x/features/posts/presentation/forms/post_form_field.dart';
import 'package:flutter_x/features/posts/presentation/view_models/post_view_model.dart';

import '../../posts_dispatcher_fixture.dart';

import '../../../../core/execution/execution_context_fixture.dart';

void main() {
  const post = Post(
    id: 1,
    userId: 1,
    title: 'First post',
    body: 'The body of the first post.',
  );

  group('PostViewModel with TestCqrsDispatcher', () {
    test('loads posts via stubbed query and verifies query dispatch', () async {
      final dispatcher = TestCqrsDispatcher();
      dispatcher.whenQuery<GetPostsQuery, List<Post>>((_) => const [post]);

      final viewModel = PostViewModel(
        dispatcher: dispatcher,
        context: testContext(),
      );
      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.posts.value.value, [post]);
      expect(dispatcher.hasQueried<GetPostsQuery>(), isTrue);
      expect(dispatcher.queriesOfType<GetPostsQuery>(), hasLength(1));
    });

    test(
      'dispatches CreatePostCommand and tracks invocation history',
      () async {
        final dispatcher = TestCqrsDispatcher();
        dispatcher.whenQuery<GetPostsQuery, List<Post>>((_) => const [post]);
        dispatcher.whenCommandValue<CreatePostCommand, Post>(
          const Post(id: 99, userId: 1, title: 'New Title', body: 'New Body'),
        );

        final viewModel = PostViewModel(
          dispatcher: dispatcher,
          context: testContext(),
        );
        addTearDown(viewModel.dispose);

        viewModel.createFormController.setValues({
          PostFormField.title: 'New Title',
          PostFormField.body: 'New Body',
        });

        final result = await viewModel.createPost();

        expect(result.isSuccess, isTrue);
        expect(dispatcher.hasDispatched<CreatePostCommand>(), isTrue);
        expect(
          dispatcher.commandsOfType<CreatePostCommand>().single.title,
          'New Title',
        );
      },
    );

    test('postsDispatcher fixture returns TestCqrsDispatcher with handler fallback & override', () async {
      // postsDispatcher returns TestCqrsDispatcher pre-wired with real module handlers
      final dispatcher = postsDispatcher(InMemoryPostRepository());

      // Override just GetPostsQuery with a stubbed return value
      dispatcher.whenQueryValue<GetPostsQuery, List<Post>>(const [post]);

      final viewModel = PostViewModel(
        dispatcher: dispatcher,
        context: testContext(),
      );
      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.posts.value.value, [post]);
      expect(dispatcher.hasQueried<GetPostsQuery>(), isTrue);
    });
  });
}
