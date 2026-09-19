import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/posts/domain/usecases/get_comments_query.dart';
import 'package:mocktail/mocktail.dart';

import '../entities/comment_fixture.dart';
import '../repositories/mock_comment_repository.dart';

void main() {
  group('GetCommentsQueryHandler', () {
    late MockCommentRepository comments;
    late GetCommentsQueryHandler handler;

    setUp(() {
      comments = MockCommentRepository();
      handler = GetCommentsQueryHandler(comments);
    });

    test(
      'should ask for the comments under the post the query names',
      () async {
        when(
          () => comments.commentsForPost(
            1,
            cancellation: any(named: 'cancellation'),
          ),
        ).thenAnswer((_) async => const [comment]);

        final loaded = await handler.execute(const GetCommentsQuery(1));

        expect(loaded, const [comment]);
        verify(
          () => comments.commentsForPost(
            1,
            cancellation: any(named: 'cancellation'),
          ),
        ).called(1);
      },
    );

    test('should hand the read the token it was given', () async {
      final token = Completer<void>().future;
      when(() => comments.commentsForPost(1, cancellation: token))
          .thenAnswer((_) async => const []);

      await handler.execute(GetCommentsQuery(1, cancellation: token));

      verify(() => comments.commentsForPost(1, cancellation: token)).called(1);
    });

    test('should resolve a post with no comments to an empty list', () async {
      when(
        () => comments.commentsForPost(
          2,
          cancellation: any(named: 'cancellation'),
        ),
      ).thenAnswer((_) async => const []);

      expect(await handler.execute(const GetCommentsQuery(2)), isEmpty);
    });
  });
}
