import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/posts/domain/entities/post.dart';
import 'package:flutter_x/features/posts/infrastructure/repositories/in_memory_post_repository.dart';

import '../../domain/entities/post_fixture.dart';

void main() {
  group('InMemoryPostRepository', () {
    late InMemoryPostRepository repository;

    setUp(() => repository = InMemoryPostRepository());

    test('should return the whole fixture', () async {
      final posts = await repository.allPosts();

      expect(posts, isNotEmpty);
      expect(posts.first, post);
    });

    test(
      'should not let a reader append through the list it returns',
      () async {
        final posts = await repository.allPosts();

        expect(() => posts.add(post), throwsUnsupportedError);
      },
    );

    test('should find a post by id', () async {
      expect(await repository.postById(1), post);
    });

    test('should resolve an unknown id to null', () async {
      expect(await repository.postById(999), isNull);
    });

    test('should assign the next id to a created post', () async {
      final created = await repository.createPost(
        userId: 2,
        title: 'Fourth post',
        body: 'Body four',
      );

      // The fixture ends at 3.
      expect(created.id, 4);
      expect(created.userId, 2);
      expect(created.title, 'Fourth post');
    });

    test('should hand a created post back to the next read', () async {
      final created = await repository.createPost(
        userId: 1,
        title: 'Fourth post',
        body: 'Body four',
      );

      expect(await repository.allPosts(), contains(created));
      expect(await repository.postById(created.id), created);
    });

    test('should replace the edited fields and keep the author', () async {
      final updated = await repository.updatePost(
        id: 2,
        title: 'Edited',
        body: 'Edited body',
      );

      // Post 2 was written by user 1; an edit does not reassign it.
      expect(
        updated,
        const Post(id: 2, userId: 1, title: 'Edited', body: 'Edited body'),
      );
      expect(await repository.postById(2), updated);
    });

    test('should refuse to edit a post that is not there', () async {
      await expectLater(
        repository.updatePost(id: 999, title: 'Edited', body: 'Body'),
        throwsArgumentError,
      );
    });

    test('should remove a deleted post from the next read', () async {
      await repository.deletePost(1);

      expect(await repository.postById(1), isNull);
      expect(await repository.allPosts(), hasLength(2));
    });

    test('should treat deleting what is already gone as done', () async {
      await repository.deletePost(999);
      await repository.deletePost(999);

      expect(await repository.allPosts(), hasLength(3));
    });
  });
}
