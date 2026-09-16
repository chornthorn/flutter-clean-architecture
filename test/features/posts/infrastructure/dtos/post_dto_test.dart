import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/posts/infrastructure/dtos/post_dto.dart';

void main() {
  group('PostDto', () {
    test('should read the wire shape', () {
      final dto = PostDto.fromJson(const {
        'userId': 7,
        'id': 3,
        'title': 'A title',
        'body': 'A body',
      });

      expect(dto.id, 3);
      expect(dto.userId, 7);
      expect(dto.title, 'A title');
      expect(dto.body, 'A body');
    });

    test('should map to the entity the domain expects', () {
      const dto = PostDto(id: 3, userId: 7, title: 'A title', body: 'A body');

      expect(dto.toDomain().toString(), 'Post(3, A title)');
      expect(dto.toDomain().userId, 7);
      expect(dto.toDomain().body, 'A body');
    });

    test('should fail loudly on a field the payload does not have', () {
      // A missing or mistyped field is a broken contract, not a null to hide.
      expect(() => PostDto.fromJson(const {'id': 3}), throwsA(anything));
    });
  });
}
