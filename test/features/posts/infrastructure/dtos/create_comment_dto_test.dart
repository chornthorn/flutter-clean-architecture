import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/posts/infrastructure/dtos/create_comment_dto.dart';

void main() {
  group('CreateCommentDto', () {
    test('should send exactly the fields the create endpoint takes', () {
      const dto = CreateCommentDto(
        postId: 1,
        name: 'Ada Lovelace',
        email: 'ada@example.com',
        body: 'A comment',
      );

      expect(dto.toJson(), {
        'postId': 1,
        'name': 'Ada Lovelace',
        'email': 'ada@example.com',
        'body': 'A comment',
      });
    });

    test('should not send an id', () {
      // The server assigns it. A placeholder in the payload would be a lie.
      const dto = CreateCommentDto(
        postId: 1,
        name: 'Ada Lovelace',
        email: 'ada@example.com',
        body: 'A comment',
      );

      expect(dto.toJson().containsKey('id'), isFalse);
    });
  });
}
