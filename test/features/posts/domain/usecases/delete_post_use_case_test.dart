import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/posts/domain/usecases/delete_post_use_case.dart';
import 'package:mocktail/mocktail.dart';

import '../repositories/mock_post_repository.dart';

void main() {
  group('DeletePostUseCase', () {
    test('should ask the store to remove the post it is given', () async {
      final posts = MockPostRepository();
      when(() => posts.deletePost(3)).thenAnswer((_) async {});

      await DeletePostUseCase(posts)(3);

      verify(() => posts.deletePost(3)).called(1);
    });

    test('should let a store failure escape', () async {
      final posts = MockPostRepository();
      when(() => posts.deletePost(3))
          .thenAnswer((_) async => throw Exception('offline'));

      await expectLater(DeletePostUseCase(posts)(3), throwsException);
    });
  });
}
