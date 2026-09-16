import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/posts/infrastructure/repositories/in_memory_post_repository.dart';
import 'package:flutter_x/features/posts/presentation/posts_revision.dart';
import 'package:flutter_x/features/posts/presentation/view_models/post_detail_view_model.dart';
import 'package:flutter_x/features/posts/presentation/views/post_detail_view.dart';
import 'package:flutter_x/features/posts/presentation/widgets/post_form_dialog.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../app/view_host.dart';
import '../../domain/entities/post_fixture.dart';
import '../../domain/repositories/mock_post_repository.dart';
import '../../posts_dispatcher_fixture.dart';

void main() {
  group('PostDetailView', () {
    testWidgets('should render the post the view model holds', (tester) async {
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

      await tester.pumpWidget(
        hostSignalPage(viewModel, const PostDetailView(id: 1)),
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

      final viewModel = PostDetailViewModel(
        postsDispatcher(repository),
        PostsRevision(),
      );
      addTearDown(viewModel.dispose);
      await viewModel.load(999);

      await tester.pumpWidget(
        hostSignalPage(viewModel, const PostDetailView(id: 999)),
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

      final viewModel = PostDetailViewModel(
        postsDispatcher(repository),
        PostsRevision(),
      );
      addTearDown(viewModel.dispose);
      await viewModel.load(1);

      await tester.pumpWidget(
        hostSignalPage(viewModel, const PostDetailView(id: 1)),
      );

      expect(find.text('Could not load post.'), findsOneWidget);
      expect(find.text('Post not found.'), findsNothing);
    });

    testWidgets('should edit the post through the dialog', (tester) async {
      final viewModel = PostDetailViewModel(
        postsDispatcher(InMemoryPostRepository()),
        PostsRevision(),
      );
      addTearDown(viewModel.dispose);
      await viewModel.load(1);

      await tester.pumpWidget(
        hostSignalPage(viewModel, const PostDetailView(id: 1)),
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
      final viewModel = PostDetailViewModel(
        postsDispatcher(store),
        PostsRevision(),
      );
      addTearDown(viewModel.dispose);
      await viewModel.load(1);

      await tester.pumpWidget(
        hostSignalPage(viewModel, const PostDetailView(id: 1)),
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
      when(
        () => store.postById(1, cancellation: any(named: 'cancellation')),
      ).thenAnswer((_) async => post);
      // The delete never answers, so the page stays on the in-flight state.
      final inFlight = Completer<void>();
      when(() => store.deletePost(any())).thenAnswer((_) => inFlight.future);

      final viewModel = PostDetailViewModel(
        postsDispatcher(store),
        PostsRevision(),
      );
      addTearDown(viewModel.dispose);
      await viewModel.load(1);

      await tester.pumpWidget(
        hostSignalPage(viewModel, const PostDetailView(id: 1)),
      );

      await tester.tap(find.byTooltip('Delete post'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // The page reads the write's own state, so neither action starts a second
      // one while the first is unanswered.
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
  });
}
