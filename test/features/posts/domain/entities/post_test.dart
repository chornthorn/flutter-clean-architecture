import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/posts/domain/entities/post.dart';

import 'post_fixture.dart';

void main() {
  group('Post', () {
    test('should be equal when every field matches', () {
      expect(
        const Post(id: 1, userId: 1, title: 'First post', body: 'Body'),
        const Post(id: 1, userId: 1, title: 'First post', body: 'Body'),
      );
    });

    test('should differ when any field does', () {
      // Guards the hand-written comparison: one field is not enough.
      expect(
        post,
        isNot(
          const Post(
            id: 2,
            userId: 1,
            title: 'First post',
            body: 'The first post in the local fixture.',
          ),
        ),
      );
    });
  });
}
