import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/posts/domain/entities/post.dart';
import 'package:flutter_x/features/posts/presentation/view_models/posts_home_view_model.dart';
import 'package:flutter_x/features/posts/presentation/views/posts_home_view.dart';
import 'package:mocktail/mocktail.dart';

import '../../domain/entities/post_fixture.dart';
import '../../domain/repositories/mock_post_repository.dart';
import '../../posts_dispatcher_fixture.dart';
import 'view_host.dart';

void main() {
  group('PostsHomeView', () {
    testWidgets('should show a spinner while the list loads', (tester) async {
      final repository = MockPostRepository();
      when(
        () => repository.allPosts(),
      ).thenAnswer((_) => Completer<List<Post>>().future);
      final viewModel = PostsHomeViewModel(postsDispatcher(repository));
      addTearDown(viewModel.dispose);
      unawaited(viewModel.load());

      await tester.pumpWidget(hostPage(viewModel, const PostsHomeView()));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should render the posts the view model holds', (tester) async {
      final repository = MockPostRepository();
      when(() => repository.allPosts()).thenAnswer((_) async => const [post]);
      final viewModel = PostsHomeViewModel(postsDispatcher(repository));
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
      final viewModel = PostsHomeViewModel(postsDispatcher(repository));
      addTearDown(viewModel.dispose);
      await viewModel.load();

      await tester.pumpWidget(hostPage(viewModel, const PostsHomeView()));

      expect(find.text('Could not load posts.'), findsOneWidget);
    });
  });
}
