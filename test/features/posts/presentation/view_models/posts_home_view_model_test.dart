import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/posts/presentation/view_models/posts_home_view_model.dart';
import 'package:mocktail/mocktail.dart';

import '../../domain/entities/post_fixture.dart';
import '../../domain/repositories/mock_post_repository.dart';
import '../../posts_dispatcher_fixture.dart';

void main() {
  group('PostsHomeViewModel', () {
    test('should report loading until the list arrives', () async {
      final repository = MockPostRepository();
      when(() => repository.allPosts()).thenAnswer((_) async => const [post]);

      final viewModel = PostsHomeViewModel(postsDispatcher(repository));
      addTearDown(viewModel.dispose);

      final load = viewModel.load();
      expect(viewModel.isLoading, isTrue);
      expect(viewModel.posts, isNull);

      await load;
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.posts, const [post]);
    });

    test('should hold a failure in error instead of throwing', () async {
      final repository = MockPostRepository();
      when(
        () => repository.allPosts(),
      ).thenAnswer((_) async => throw Exception('offline'));

      final viewModel = PostsHomeViewModel(postsDispatcher(repository));
      addTearDown(viewModel.dispose);

      await expectLater(viewModel.load(), completes);

      expect(viewModel.error, isA<Exception>());
      expect(viewModel.posts, isNull);
    });
  });
}
