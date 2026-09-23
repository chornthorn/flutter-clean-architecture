import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/core/presentation/action_result.dart';
import 'package:flutter_x/core/presentation/form/app_form_controller.dart';
import 'package:flutter_x/features/posts/domain/entities/comment.dart';
import 'package:flutter_x/features/posts/infrastructure/repositories/in_memory_comment_repository.dart';
import 'package:flutter_x/features/posts/presentation/forms/comment_form_field.dart';
import 'package:mocktail/mocktail.dart';
import 'package:signals/signals_flutter.dart';

import '../../domain/entities/comment_fixture.dart';
import '../../domain/repositories/mock_comment_repository.dart';
import '../../posts_view_model_fixture.dart';

void main() {
  group('CommentViewModel', () {
    test('should report loading until the thread arrives', () async {
      final repository = MockCommentRepository();
      when(
        () => repository.commentsForPost(
          1,
          cancellation: any(named: 'cancellation'),
        ),
      ).thenAnswer((_) async => const [comment]);

      final viewModel = commentsViewModel(repository);
      addTearDown(viewModel.dispose);

      expect(viewModel.comments.value.isLoading, isTrue);

      await viewModel.load(1);

      expect(viewModel.comments.value.isLoading, isFalse);
      expect(viewModel.comments.value.value, const [comment]);
    });

    test('should resolve a post with no comments to an empty list', () async {
      final repository = MockCommentRepository();
      when(
        () => repository.commentsForPost(
          2,
          cancellation: any(named: 'cancellation'),
        ),
      ).thenAnswer((_) async => const []);

      final viewModel = commentsViewModel(repository);
      addTearDown(viewModel.dispose);

      await viewModel.load(2);

      expect(viewModel.comments.value.hasError, isFalse);
      expect(viewModel.comments.value.value, isEmpty);
    });

    test('should hold a failure in error instead of throwing', () async {
      final repository = MockCommentRepository();
      when(
        () => repository.commentsForPost(
          1,
          cancellation: any(named: 'cancellation'),
        ),
      ).thenAnswer((_) async => throw Exception('offline'));

      final viewModel = commentsViewModel(repository);
      addTearDown(viewModel.dispose);

      await viewModel.load(1);

      expect(viewModel.comments.value.hasError, isTrue);
      expect(viewModel.comments.value.value, isNull);
    });

    test(
      'should start the write settled, so the page does not read it in flight',
      () {
        final viewModel = commentsViewModel(InMemoryCommentRepository());
        addTearDown(viewModel.dispose);

        expect(viewModel.create.value.isLoading, isFalse);
        expect(viewModel.create.value.hasError, isFalse);
      },
    );

    test(
      'should add the comment the store records to the thread it holds',
      () async {
        final viewModel = commentsViewModel(InMemoryCommentRepository());
        addTearDown(viewModel.dispose);
        await viewModel.load(1);

        viewModel.prepareCreate();
        viewModel.commentFormController.setValues({
          CommentFormField.name: 'Ada Lovelace',
          CommentFormField.email: 'ada@example.com',
          CommentFormField.body: 'A new comment',
        });

        final created = await viewModel.createComment(1);

        expect(created.isSuccess, isTrue);
        expect(viewModel.create.value.hasError, isFalse);
        expect(viewModel.commentFormController.hasErrors, isFalse);
        // The fixture ends at 3, so 4 is the id the store assigned.
        expect(
          viewModel.comments.value.value,
          contains(
            const Comment(
              id: 4,
              postId: 1,
              name: 'Ada Lovelace',
              email: 'ada@example.com',
              body: 'A new comment',
            ),
          ),
        );
        expect(
          viewModel.commentFormController.text(
            const FormFieldKey(CommentFormField.name),
          ),
          isEmpty,
        );
      },
    );

    test(
      'should keep the thread off the post a comment was added to',
      () async {
        final viewModel = commentsViewModel(InMemoryCommentRepository());
        addTearDown(viewModel.dispose);
        await viewModel.load(1);

        viewModel.commentFormController.setValues({
          CommentFormField.name: 'Ada Lovelace',
          CommentFormField.email: 'ada@example.com',
          CommentFormField.body: 'A new comment',
        });
        await viewModel.createComment(2);
        await viewModel.load(1);

        // Post 1 still reads the two comments the fixture gave it.
        expect(viewModel.comments.value.value, hasLength(2));
      },
    );

    test('should return ActionFailure with field errors and bind to commentFormController when validation fails', () async {
      final viewModel = commentsViewModel(InMemoryCommentRepository());
      addTearDown(viewModel.dispose);

      viewModel.commentFormController.setValues({
        CommentFormField.name: 'Ada Lovelace',
        CommentFormField.email: 'ada.example.com',
        CommentFormField.body: 'A new comment',
      });

      final result = await viewModel.createComment(1);

      expect(result.isFailure, isTrue);
      expect((result as ActionFailure).fieldErrors, {
        'email': 'Enter an email address like ada@example.com.',
      });
      expect(
        viewModel.commentFormController[const FormFieldKey(
          CommentFormField.email,
        )],
        'Enter an email address like ada@example.com.',
      );
    });

    test(
      'should keep the failure and answer failure when a create fails',
      () async {
        final repository = MockCommentRepository();
        when(
          () => repository.commentsForPost(
            1,
            cancellation: any(named: 'cancellation'),
          ),
        ).thenAnswer((_) async => const [comment]);
        when(
          () => repository.createComment(
            postId: any(named: 'postId'),
            name: any(named: 'name'),
            email: any(named: 'email'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => throw Exception('offline'));

        final viewModel = commentsViewModel(repository);
        addTearDown(viewModel.dispose);
        await viewModel.load(1);

        viewModel.commentFormController.setValues({
          CommentFormField.name: 'Ada Lovelace',
          CommentFormField.email: 'ada@example.com',
          CommentFormField.body: 'A new comment',
        });

        final created = await viewModel.createComment(1);

        expect(created.isFailure, isTrue);
        expect(viewModel.create.value.hasError, isTrue);
        // The thread the write failed to grow is still the one on screen.
        expect(viewModel.comments.value.value, const [comment]);
      },
    );

    test('should stay silent when a thread load outlives its view', () async {
      final completer = Completer<List<Comment>>();
      final repository = MockCommentRepository();
      when(
        () => repository.commentsForPost(
          1,
          cancellation: any(named: 'cancellation'),
        ),
      ).thenAnswer((_) => completer.future);

      final viewModel = commentsViewModel(repository);
      final pushed = <AsyncState<List<Comment>>>[];
      addTearDown(viewModel.comments.subscribe(pushed.add));

      final load = viewModel.load(1);
      viewModel.dispose();
      completer.complete(const [comment]);

      await expectLater(load, completes);

      expect(pushed, isNotEmpty);
      expect(pushed.every((state) => state.isLoading), isTrue);
    });
  });
}
