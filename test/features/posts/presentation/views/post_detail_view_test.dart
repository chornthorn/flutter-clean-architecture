import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/posts/presentation/view_models/post_detail_view_model.dart';
import 'package:flutter_x/features/posts/presentation/views/post_detail_view.dart';
import 'package:mocktail/mocktail.dart';

import '../../domain/entities/post_fixture.dart';
import '../../domain/repositories/mock_post_repository.dart';
import '../../posts_dispatcher_fixture.dart';
import 'view_host.dart';

void main() {
  group('PostDetailView', () {
    testWidgets('should render the post the view model holds', (tester) async {
      final repository = MockPostRepository();
      when(() => repository.postById(1)).thenAnswer((_) async => post);

      final viewModel = PostDetailViewModel(postsDispatcher(repository));
      addTearDown(viewModel.dispose);
      await viewModel.load(1);

      await tester.pumpWidget(hostPage(viewModel, const PostDetailView(id: 1)));

      expect(find.widgetWithText(AppBar, 'Post 1'), findsOneWidget);
      expect(find.text('First post'), findsOneWidget);
      expect(find.text('The first post in the local fixture.'), findsOneWidget);
    });

    testWidgets('should render the not-found state', (tester) async {
      final repository = MockPostRepository();
      when(() => repository.postById(999)).thenAnswer((_) async => null);

      final viewModel = PostDetailViewModel(postsDispatcher(repository));
      addTearDown(viewModel.dispose);
      await viewModel.load(999);

      await tester.pumpWidget(
        hostPage(viewModel, const PostDetailView(id: 999)),
      );

      expect(find.text('Post not found.'), findsOneWidget);
    });

    testWidgets('should tell a failure apart from a missing post', (
      tester,
    ) async {
      final repository = MockPostRepository();
      when(
        () => repository.postById(1),
      ).thenAnswer((_) async => throw Exception('offline'));

      final viewModel = PostDetailViewModel(postsDispatcher(repository));
      addTearDown(viewModel.dispose);
      await viewModel.load(1);

      await tester.pumpWidget(hostPage(viewModel, const PostDetailView(id: 1)));

      expect(find.text('Could not load post.'), findsOneWidget);
      expect(find.text('Post not found.'), findsNothing);
    });
  });
}
