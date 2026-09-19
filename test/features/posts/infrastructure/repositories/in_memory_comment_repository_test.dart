import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/posts/infrastructure/repositories/in_memory_comment_repository.dart';

import '../../domain/entities/comment_fixture.dart';

void main() {
  group('InMemoryCommentRepository', () {
    late InMemoryCommentRepository repository;

    setUp(() => repository = InMemoryCommentRepository());

    test('should return the comments of the post it is asked for', () async {
      final comments = await repository.commentsForPost(1);

      expect(comments, hasLength(2));
      expect(comments.first, comment);
    });

    test(
      'should not let a reader append through the list it returns',
      () async {
        final comments = await repository.commentsForPost(1);

        expect(() => comments.add(comment), throwsUnsupportedError);
      },
    );

    test('should resolve a post with no comments to an empty list', () async {
      expect(await repository.commentsForPost(999), isEmpty);
    });

    test('should assign the next id to a created comment', () async {
      final created = await repository.createComment(
        postId: 1,
        name: 'Ada Lovelace',
        email: 'ada@example.com',
        body: 'A new comment',
      );

      // The fixture ends at 3.
      expect(created.id, 4);
      expect(created.postId, 1);
      expect(created.body, 'A new comment');
    });

    test('should hand a created comment back to the next read', () async {
      final created = await repository.createComment(
        postId: 1,
        name: 'Ada Lovelace',
        email: 'ada@example.com',
        body: 'A new comment',
      );

      expect(await repository.commentsForPost(1), contains(created));
    });

    test('should keep a comment off the post it does not belong to', () async {
      final created = await repository.createComment(
        postId: 2,
        name: 'Ada Lovelace',
        email: 'ada@example.com',
        body: 'A new comment',
      );

      expect(await repository.commentsForPost(2), contains(created));
      expect(await repository.commentsForPost(1), hasLength(2));
    });
  });
}
