import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/posts/domain/entities/comment.dart';
import 'package:flutter_x/features/posts/domain/repositories/comment_repository.dart';
import 'package:flutter_x/features/posts/infrastructure/repositories/in_memory_comment_repository.dart';
import 'package:flutter_x/features/posts/infrastructure/repositories/in_memory_post_repository.dart';
import 'package:flutter_x/features/posts/presentation/view_models/comment_view_model.dart';
import 'package:flutter_x/features/posts/presentation/view_models/post_view_model.dart';
import 'package:flutter_x/features/posts/presentation/views/post_detail_view.dart';
import 'package:flutter_x/features/posts/presentation/widgets/comment_form_dialog.dart';
import 'package:flutter_x/features/posts/presentation/widgets/post_form_dialog.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import '../../../../app/view_host.dart';
import '../../domain/entities/comment_fixture.dart';
import '../../domain/entities/post_fixture.dart';
import '../../domain/repositories/mock_comment_repository.dart';
import '../../domain/repositories/mock_post_repository.dart';
import '../../posts_dispatcher_fixture.dart';

import '../../../../core/execution/execution_context_fixture.dart';

void main() {
  // The detail page reads two view models: the post's, and the thread's.
  Widget hostDetail(
    PostViewModel posts,
    CommentViewModel comments,
    Widget page,
  ) => hostSignalPage(
    posts,
    Provider<CommentViewModel>.value(value: comments, child: page),
  );

  // A thread that has finished loading, so the page under test is not left mid-spin.
  Future<CommentViewModel> loadedComments({
    int postId = 1,
    CommentRepository? repository,
  }) async {
    final viewModel = CommentViewModel(
      dispatcher: commentsDispatcher(repository ?? InMemoryCommentRepository()),
      context: testContext(),
    );
    addTearDown(viewModel.dispose);
    await viewModel.load(postId);
    return viewModel;
  }

  group('PostDetailView', () {
    testWidgets('should render the post the view model holds', (tester) async {
      final repository = MockPostRepository();
      when(
        () => repository.postById(1, cancellation: any(named: 'cancellation')),
      ).thenAnswer((_) async => post);

      final viewModel = PostViewModel(
        dispatcher: postsDispatcher(repository),
        context: testContext(),
      );
      addTearDown(viewModel.dispose);
      await viewModel.load(1);
      final comments = await loadedComments();

      await tester.pumpWidget(
        hostDetail(viewModel, comments, const PostDetailView(id: 1)),
      );

      expect(find.widgetWithText(AppBar, 'Post 1'), findsOneWidget);
      expect(find.text('First post'), findsOneWidget);
      expect(find.text('The first post in the local fixture.'), findsOneWidget);
    });

    testWidgets('should render the not-found state', (tester) async {
      final repository = MockPostRepository();
      when(
        () =>
            repository.postById(999, cancellation: any(named: 'cancellation')),
      ).thenAnswer((_) async => null);

      final viewModel = PostViewModel(
        dispatcher: postsDispatcher(repository),
        context: testContext(),
      );
      addTearDown(viewModel.dispose);
      await viewModel.load(999);
      final comments = await loadedComments(postId: 999);

      await tester.pumpWidget(
        hostDetail(viewModel, comments, const PostDetailView(id: 999)),
      );

      expect(find.text('Post not found.'), findsOneWidget);
    });

    testWidgets('should tell a failure apart from a missing post', (
      tester,
    ) async {
      final repository = MockPostRepository();
      when(
        () => repository.postById(1, cancellation: any(named: 'cancellation')),
      ).thenAnswer((_) async => throw Exception('offline'));

      final viewModel = PostViewModel(
        dispatcher: postsDispatcher(repository),
        context: testContext(),
      );
      addTearDown(viewModel.dispose);
      await viewModel.load(1);
      final comments = await loadedComments();

      await tester.pumpWidget(
        hostDetail(viewModel, comments, const PostDetailView(id: 1)),
      );

      expect(find.text('Could not load post.'), findsOneWidget);
      expect(find.text('Post not found.'), findsNothing);
    });

    testWidgets('should edit the post through the dialog', (tester) async {
      final viewModel = PostViewModel(
        dispatcher: postsDispatcher(InMemoryPostRepository()),
        context: testContext(),
      );
      addTearDown(viewModel.dispose);
      await viewModel.load(1);
      final comments = await loadedComments();

      await tester.pumpWidget(
        hostDetail(viewModel, comments, const PostDetailView(id: 1)),
      );

      await tester.tap(find.byTooltip('Edit post'));
      await tester.pumpAndSettle();
      // The form opens on the post that is on screen, not on empty fields.
      expect(find.byType(PostFormDialog), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'Edited title',
      );
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.byType(PostFormDialog), findsNothing);
      expect(find.text('Edited title'), findsOneWidget);
      expect(find.text('First post'), findsNothing);
    });

    testWidgets('should ask before deleting, and stop when told no', (
      tester,
    ) async {
      final store = InMemoryPostRepository();
      final viewModel = PostViewModel(
        dispatcher: postsDispatcher(store),
        context: testContext(),
      );
      addTearDown(viewModel.dispose);
      await viewModel.load(1);
      final comments = await loadedComments();

      await tester.pumpWidget(
        hostDetail(viewModel, comments, const PostDetailView(id: 1)),
      );

      await tester.tap(find.byTooltip('Delete post'));
      await tester.pumpAndSettle();
      expect(find.text('Delete this post?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Backing out leaves the post where it was.
      expect(await store.postById(1), isNotNull);
      expect(find.byType(PostDetailView), findsOneWidget);
    });

    testWidgets('should hold both actions while a write is on the wire', (
      tester,
    ) async {
      final store = MockPostRepository();
      when(() => store.postById(1, cancellation: any(named: 'cancellation')))
          .thenAnswer((_) async => post);
      // The delete never answers, so the page stays on the in-flight state.
      final inFlight = Completer<void>();
      when(() => store.deletePost(any())).thenAnswer((_) => inFlight.future);

      final viewModel = PostViewModel(
        dispatcher: postsDispatcher(store),
        context: testContext(),
      );
      addTearDown(viewModel.dispose);
      await viewModel.load(1);
      final comments = await loadedComments();

      await tester.pumpWidget(
        hostDetail(viewModel, comments, const PostDetailView(id: 1)),
      );

      await tester.tap(find.byTooltip('Delete post'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // The page reads the write's own state, so neither action starts a second one.
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.delete_outline),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.edit_outlined),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('should render the comments the post already has', (
      tester,
    ) async {
      final viewModel = PostViewModel(
        dispatcher: postsDispatcher(InMemoryPostRepository()),
        context: testContext(),
      );
      addTearDown(viewModel.dispose);
      await viewModel.load(1);
      final comments = await loadedComments();

      await tester.pumpWidget(
        hostDetail(viewModel, comments, const PostDetailView(id: 1)),
      );

      expect(find.text('Comments'), findsOneWidget);
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('ada@example.com'), findsOneWidget);
      expect(
        find.text('The second comment on the first post.'),
        findsOneWidget,
      );
    });

    testWidgets('should say so when the post has no comments yet', (
      tester,
    ) async {
      final viewModel = PostViewModel(
        dispatcher: postsDispatcher(InMemoryPostRepository()),
        context: testContext(),
      );
      addTearDown(viewModel.dispose);
      await viewModel.load(3);
      final comments = await loadedComments(postId: 3);

      await tester.pumpWidget(
        hostDetail(viewModel, comments, const PostDetailView(id: 3)),
      );

      expect(find.text('No comments yet.'), findsOneWidget);
    });

    testWidgets('should add a comment through the dialog', (tester) async {
      final viewModel = PostViewModel(
        dispatcher: postsDispatcher(InMemoryPostRepository()),
        context: testContext(),
      );
      addTearDown(viewModel.dispose);
      await viewModel.load(1);
      final comments = await loadedComments();

      await tester.pumpWidget(
        hostDetail(viewModel, comments, const PostDetailView(id: 1)),
      );

      await tester.ensureVisible(find.text('Add comment'));
      await tester.tap(find.text('Add comment'));
      await tester.pumpAndSettle();
      expect(find.byType(CommentFormDialog), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'Alan Turing',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Email'),
        'alan@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Body'),
        'A comment from the test',
      );
      await tester.pump();
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.byType(CommentFormDialog), findsNothing);
      expect(find.text('A comment from the test'), findsOneWidget);
      expect(find.text('Alan Turing'), findsOneWidget);
    });

    testWidgets('should offer to read the thread again after a failure', (
      tester,
    ) async {
      final repository = MockCommentRepository();
      var attempts = 0;
      when(
        () => repository.commentsForPost(
          1,
          cancellation: any(named: 'cancellation'),
        ),
      ).thenAnswer((_) async {
        attempts++;
        // Fails once, then answers, so the retry has something to show.
        if (attempts == 1) throw Exception('offline');
        return const [comment];
      });

      final viewModel = PostViewModel(
        dispatcher: postsDispatcher(InMemoryPostRepository()),
        context: testContext(),
      );
      addTearDown(viewModel.dispose);
      await viewModel.load(1);
      final comments = await loadedComments(repository: repository);

      await tester.pumpWidget(
        hostDetail(viewModel, comments, const PostDetailView(id: 1)),
      );
      expect(find.text('Could not load comments.'), findsOneWidget);

      await tester.ensureVisible(find.text('Try again'));
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Could not load comments.'), findsNothing);
      expect(find.text('Ada Lovelace'), findsOneWidget);
    });

    testWidgets('should hold the add button while a comment is on the wire', (
      tester,
    ) async {
      final repository = MockCommentRepository();
      when(
        () => repository.commentsForPost(
          1,
          cancellation: any(named: 'cancellation'),
        ),
      ).thenAnswer((_) async => const [comment]);
      // The write never answers, so the page stays on the in-flight state.
      final inFlight = Completer<Comment>();
      when(
        () => repository.createComment(
          postId: any(named: 'postId'),
          name: any(named: 'name'),
          email: any(named: 'email'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) => inFlight.future);

      final viewModel = PostViewModel(
        dispatcher: postsDispatcher(InMemoryPostRepository()),
        context: testContext(),
      );
      addTearDown(viewModel.dispose);
      await viewModel.load(1);
      final comments = await loadedComments(repository: repository);

      await tester.pumpWidget(
        hostDetail(viewModel, comments, const PostDetailView(id: 1)),
      );

      await tester.ensureVisible(find.text('Add comment'));
      await tester.tap(find.text('Add comment'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'Alan Turing',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Email'),
        'alan@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Body'),
        'A comment from the test',
      );
      await tester.pump();
      await tester.tap(find.text('Add'));
      await tester.pump();

      // The button reads the write's own state, so it cannot start a second one.
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Add comment'),
            )
            .onPressed,
        isNull,
      );

      inFlight.complete(
        const Comment(
          id: 4,
          postId: 1,
          name: 'Alan Turing',
          email: 'alan@example.com',
          body: 'A comment from the test',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CommentFormDialog), findsNothing);
    });
  });
}
