import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/posts/infrastructure/dtos/comment_dto.dart';

void main() {
  group('CommentDto', () {
    test('should read the wire shape', () {
      final dto = CommentDto.fromJson(const {
        'postId': 1,
        'id': 5,
        'name': 'Ada Lovelace',
        'email': 'ada@example.com',
        'body': 'A comment',
      });

      expect(dto.id, 5);
      expect(dto.postId, 1);
      expect(dto.name, 'Ada Lovelace');
      expect(dto.email, 'ada@example.com');
      expect(dto.body, 'A comment');
    });

    test('should map to the entity the domain expects', () {
      const dto = CommentDto(
        id: 5,
        postId: 1,
        name: 'Ada Lovelace',
        email: 'ada@example.com',
        body: 'A comment',
      );

      expect(dto.toDomain().toString(), 'Comment(5, Ada Lovelace)');
      expect(dto.toDomain().postId, 1);
      expect(dto.toDomain().email, 'ada@example.com');
    });

    test('should fail loudly on a field the payload does not have', () {
      // A missing or mistyped field is a broken contract, not a null to hide.
      expect(() => CommentDto.fromJson(const {'id': 5}), throwsA(anything));
    });
  });
}
