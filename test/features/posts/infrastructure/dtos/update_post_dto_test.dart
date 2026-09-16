import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/posts/infrastructure/dtos/update_post_dto.dart';

void main() {
  group('UpdatePostDto', () {
    test('should send the fields an edit changes', () {
      const dto = UpdatePostDto(title: 'A title', body: 'A body');

      expect(dto.toJson(), {'title': 'A title', 'body': 'A body'});
    });

    test('should not send the id or the author', () {
      // The id is in the path; an edit does not reassign a post.
      const dto = UpdatePostDto(title: 'A title', body: 'A body');

      expect(dto.toJson().containsKey('id'), isFalse);
      expect(dto.toJson().containsKey('userId'), isFalse);
    });
  });
}
