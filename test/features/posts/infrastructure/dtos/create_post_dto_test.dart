import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/posts/infrastructure/dtos/create_post_dto.dart';

void main() {
  group('CreatePostDto', () {
    test('should send exactly the fields the create endpoint takes', () {
      const dto = CreatePostDto(userId: 7, title: 'A title', body: 'A body');

      expect(dto.toJson(), {'userId': 7, 'title': 'A title', 'body': 'A body'});
    });

    test('should not send an id', () {
      // The server assigns it. A placeholder in the payload would be a lie.
      const dto = CreatePostDto(userId: 1, title: 'A title', body: 'A body');

      expect(dto.toJson().containsKey('id'), isFalse);
    });
  });
}
