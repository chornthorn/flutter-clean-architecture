import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/posts/domain/usecases/get_comments_use_case.dart';
import 'package:mocktail/mocktail.dart';

import '../entities/comment_fixture.dart';
import '../repositories/mock_comment_repository.dart';

void main() {
  group('GetCommentsUseCase', () {
    late MockCommentRepository comments;
    late GetCommentsUseCase getComments;

    setUp(() {
      comments = MockCommentRepository();
      getComments = GetCommentsUseCase(comments);
    });

    test('should ask for the comments under the post it is given', () async {
      when(
        () => comments.commentsForPost(
          1,
          cancellation: any(named: 'cancellation'),
        ),
      ).thenAnswer((_) async => const [comment]);

      final loaded = await getComments(1);

      expect(loaded, const [comment]);
      verify(
        () => comments.commentsForPost(
          1,
          cancellation: any(named: 'cancellation'),
        ),
      ).called(1);
    });

    test('should hand the read the token it was given', () async {
      final token = Completer<void>().future;
      when(() => comments.commentsForPost(1, cancellation: token))
          .thenAnswer((_) async => const []);

      await getComments(1, cancellation: token);

      verify(() => comments.commentsForPost(1, cancellation: token)).called(1);
    });

    test('should resolve a post with no comments to an empty list', () async {
      when(
        () => comments.commentsForPost(
          2,
          cancellation: any(named: 'cancellation'),
        ),
      ).thenAnswer((_) async => const []);

      expect(await getComments(2), isEmpty);
    });
  });
}
