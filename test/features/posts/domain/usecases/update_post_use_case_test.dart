import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/core/error/app_exception.dart';
import 'package:flutter_x/features/posts/domain/entities/post.dart';
import 'package:flutter_x/features/posts/domain/usecases/update_post_use_case.dart';
import 'package:mocktail/mocktail.dart';

import '../repositories/mock_post_repository.dart';

void main() {
  group('UpdatePostUseCase', () {
    late MockPostRepository posts;
    late UpdatePostUseCase updatePost;

    setUp(() {
      posts = MockPostRepository();
      when(
        () => posts.updatePost(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (invocation) async => Post(
          id: invocation.namedArguments[#id] as int,
          userId: 1,
          title: invocation.namedArguments[#title] as String,
          body: invocation.namedArguments[#body] as String,
        ),
      );
      updatePost = UpdatePostUseCase(posts);
    });

    test('should hand the store what it was given, trimmed', () async {
      final updated = await updatePost(
        id: 3,
        title: '  An edited title  ',
        body: '  An edited body  ',
      );

      expect(updated.id, 3);
      verify(
        () => posts.updatePost(
          id: 3,
          title: 'An edited title',
          body: 'An edited body',
        ),
      ).called(1);
    });

    test('should reject an edit that would leave no title', () async {
      // The same rule as create, from the same place: `cleanedTitle`.
      await expectLater(
        updatePost(id: 3, title: '   ', body: 'A body'),
        throwsA(isA<ValidationException>()),
      );

      verifyNever(
        () => posts.updatePost(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
        ),
      );
    });

    test('should let a store failure escape', () async {
      when(
        () => posts.updatePost(
          id: any(named: 'id'),
          title: any(named: 'title'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((_) async => throw Exception('offline'));

      await expectLater(
        updatePost(id: 3, title: 'A title', body: 'A body'),
        throwsException,
      );
    });
  });
}
