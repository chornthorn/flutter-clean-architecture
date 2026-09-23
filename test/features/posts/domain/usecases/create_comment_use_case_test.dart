import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/core/error/app_exception.dart';
import 'package:flutter_x/features/posts/domain/entities/comment.dart';
import 'package:flutter_x/features/posts/domain/usecases/create_comment_use_case.dart';
import 'package:mocktail/mocktail.dart';

import '../repositories/mock_comment_repository.dart';

void main() {
  group('CreateCommentUseCase', () {
    late MockCommentRepository comments;
    late CreateCommentUseCase createComment;

    setUp(() {
      comments = MockCommentRepository();
      when(
        () => comments.createComment(
          postId: any(named: 'postId'),
          name: any(named: 'name'),
          email: any(named: 'email'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (invocation) async => Comment(
          id: 101,
          postId: invocation.namedArguments[#postId] as int,
          name: invocation.namedArguments[#name] as String,
          email: invocation.namedArguments[#email] as String,
          body: invocation.namedArguments[#body] as String,
        ),
      );
      createComment = CreateCommentUseCase(comments);
    });

    test('should hand the store what it was given', () async {
      final created = await createComment(
        postId: 1,
        name: 'Ada Lovelace',
        email: 'ada@example.com',
        body: 'A comment',
      );

      expect(created.id, 101);
      verify(
        () => comments.createComment(
          postId: 1,
          name: 'Ada Lovelace',
          email: 'ada@example.com',
          body: 'A comment',
        ),
      ).called(1);
    });

    test('should trim what the form collected', () async {
      await createComment(
        postId: 1,
        name: '  Ada Lovelace  ',
        email: '  ada@example.com  ',
        body: '  A comment  ',
      );

      verify(
        () => comments.createComment(
          postId: 1,
          name: 'Ada Lovelace',
          email: 'ada@example.com',
          body: 'A comment',
        ),
      ).called(1);
    });

    test('should reject a comment with no name', () async {
      await expectLater(
        createComment(
          postId: 1,
          name: '   ',
          email: 'ada@example.com',
          body: 'A comment',
        ),
        throwsA(isA<ValidationException>()),
      );

      verifyNever(
        () => comments.createComment(
          postId: any(named: 'postId'),
          name: any(named: 'name'),
          email: any(named: 'email'),
          body: any(named: 'body'),
        ),
      );
    });

    test('should reject a comment with no email address', () async {
      await expectLater(
        createComment(
          postId: 1,
          name: 'Ada Lovelace',
          email: '   ',
          body: 'A comment',
        ),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.fieldErrors['email'],
            'fieldErrors[email]',
            'A comment needs an email address.',
          ),
        ),
      );

      verifyNever(
        () => comments.createComment(
          postId: any(named: 'postId'),
          name: any(named: 'name'),
          email: any(named: 'email'),
          body: any(named: 'body'),
        ),
      );
    });

    test('should reject a comment with no body', () async {
      await expectLater(
        createComment(
          postId: 1,
          name: 'Ada Lovelace',
          email: 'ada@example.com',
          body: '   ',
        ),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.fieldErrors['body'],
            'fieldErrors[body]',
            'A comment needs a body.',
          ),
        ),
      );

      verifyNever(
        () => comments.createComment(
          postId: any(named: 'postId'),
          name: any(named: 'name'),
          email: any(named: 'email'),
          body: any(named: 'body'),
        ),
      );
    });
  });
}
