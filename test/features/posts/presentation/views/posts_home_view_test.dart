import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/posts/domain/entities/post.dart';
import 'package:flutter_x/features/posts/infrastructure/repositories/in_memory_post_repository.dart';
import 'package:flutter_x/features/posts/presentation/posts_watch.dart';
import 'package:flutter_x/features/posts/presentation/view_models/posts_home_view_model.dart';
import 'package:flutter_x/features/posts/presentation/views/posts_home_view.dart';
import 'package:flutter_x/features/posts/presentation/widgets/post_form_dialog.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../app/view_host.dart';
import '../../domain/entities/post_fixture.dart';
import '../../domain/repositories/mock_post_repository.dart';
import '../../posts_dispatcher_fixture.dart';

void main() {
  group('PostsHomeView', () {
    testWidgets('should show a spinner while the list loads', (tester) async {
      final repository = MockPostRepository();
      when(
        () => repository.allPosts(),
      ).thenAnswer((_) => Completer<List<Post>>().future);
      final viewModel = PostsHomeViewModel(
        postsDispatcher(repository),
        PostsWatch(),
      );
      addTearDown(viewModel.dispose);
      unawaited(viewModel.load());

      await tester.pumpWidget(hostPage(viewModel, const PostsHomeView()));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should render the posts the view model holds', (tester) async {
      final repository = MockPostRepository();
      when(() => repository.allPosts()).thenAnswer((_) async => const [post]);
      final viewModel = PostsHomeViewModel(
        postsDispatcher(repository),
        PostsWatch(),
      );
      addTearDown(viewModel.dispose);
      await viewModel.load();

      await tester.pumpWidget(hostPage(viewModel, const PostsHomeView()));

      expect(find.text('First post'), findsOneWidget);
      expect(find.text('by user 1'), findsOneWidget);
    });

    testWidgets('should render the error state', (tester) async {
      final repository = MockPostRepository();
      when(
        () => repository.allPosts(),
      ).thenAnswer((_) async => throw Exception('offline'));
      final viewModel = PostsHomeViewModel(
        postsDispatcher(repository),
        PostsWatch(),
      );
      addTearDown(viewModel.dispose);
      await viewModel.load();

      await tester.pumpWidget(hostPage(viewModel, const PostsHomeView()));

      expect(find.text('Could not load posts.'), findsOneWidget);
    });

    testWidgets('should add a post through the dialog', (tester) async {
      // A real store: the new post reaches the list only if the dialog handed it
      // to the view model, the command wrote it, and the reload read it back.
      final viewModel = PostsHomeViewModel(
        postsDispatcher(InMemoryPostRepository()),
        PostsWatch(),
      );
      addTearDown(viewModel.dispose);
      await viewModel.load();

      await tester.pumpWidget(hostPage(viewModel, const PostsHomeView()));

      await tester.tap(find.byTooltip('New post'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'Fourth post',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Body'),
        'Body four',
      );
      await tester.pump();

      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.byType(PostFormDialog), findsNothing);
      expect(find.text('Fourth post'), findsOneWidget);
    });
  });
}
