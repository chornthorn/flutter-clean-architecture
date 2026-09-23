import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/posts/domain/usecases/delete_post_use_case.dart';
import 'package:mocktail/mocktail.dart';

import '../repositories/mock_post_repository.dart';

void main() {
  group('DeletePostUseCase', () {
    test('should ask the store to remove the post it is given', () async {
      final posts = MockPostRepository();
      when(() => posts.deletePost(3, cancellation: any(named: 'cancellation')))
          .thenAnswer((_) async {});

      await DeletePostUseCase(posts)(3);

      verify(
        () => posts.deletePost(3, cancellation: any(named: 'cancellation')),
      ).called(1);
    });

    test('should carry the writer\'s way out down to the repository', () async {
      final posts = MockPostRepository();
      when(() => posts.deletePost(3, cancellation: any(named: 'cancellation')))
          .thenAnswer((_) async {});
      final walkedAway = Completer<void>();

      await DeletePostUseCase(posts)(3, cancellation: walkedAway.future);

      verify(() => posts.deletePost(3, cancellation: walkedAway.future))
          .called(1);
    });

    test('should let a store failure escape', () async {
      final posts = MockPostRepository();
      when(() => posts.deletePost(3, cancellation: any(named: 'cancellation')))
          .thenAnswer((_) async => throw Exception('offline'));

      await expectLater(DeletePostUseCase(posts)(3), throwsException);
    });
  });
}
