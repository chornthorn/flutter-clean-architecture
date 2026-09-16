import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/posts/infrastructure/repositories/in_memory_post_repository.dart';

import '../../domain/entities/post_fixture.dart';

void main() {
  group('InMemoryPostRepository', () {
    const repository = InMemoryPostRepository();

    test('should return the whole fixture', () async {
      final posts = await repository.allPosts();

      expect(posts, isNotEmpty);
      expect(posts.first, post);
    });

    test('should find a post by id', () async {
      expect(await repository.postById(1), post);
    });

    test('should resolve an unknown id to null', () async {
      expect(await repository.postById(999), isNull);
    });
  });
}
