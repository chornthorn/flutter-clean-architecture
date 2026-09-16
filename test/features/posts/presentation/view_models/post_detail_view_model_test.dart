import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/posts/presentation/view_models/post_detail_view_model.dart';
import 'package:mocktail/mocktail.dart';

import '../../domain/entities/post_fixture.dart';
import '../../domain/repositories/mock_post_repository.dart';
import '../../posts_dispatcher_fixture.dart';

void main() {
  group('PostDetailViewModel', () {
    test('should load the post the query returns', () async {
      final repository = MockPostRepository();
      when(() => repository.postById(1)).thenAnswer((_) async => post);

      final viewModel = PostDetailViewModel(postsDispatcher(repository));
      addTearDown(viewModel.dispose);

      await viewModel.load(1);

      expect(viewModel.post, post);
      expect(viewModel.error, isNull);
      expect(viewModel.isLoading, isFalse);
    });

    test('should resolve an unknown id to a null post, not an error', () async {
      final repository = MockPostRepository();
      when(() => repository.postById(999)).thenAnswer((_) async => null);

      final viewModel = PostDetailViewModel(postsDispatcher(repository));
      addTearDown(viewModel.dispose);

      await viewModel.load(999);

      expect(viewModel.post, isNull);
      expect(viewModel.error, isNull);
      expect(viewModel.isLoading, isFalse);
    });

    test('should hold a failure in error instead of throwing', () async {
      final repository = MockPostRepository();
      when(
        () => repository.postById(1),
      ).thenAnswer((_) async => throw Exception('offline'));

      final viewModel = PostDetailViewModel(postsDispatcher(repository));
      addTearDown(viewModel.dispose);

      await expectLater(viewModel.load(1), completes);

      expect(viewModel.error, isA<Exception>());
      expect(viewModel.post, isNull);
    });
  });
}
