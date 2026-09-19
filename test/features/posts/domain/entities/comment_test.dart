import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/core/error/app_exception.dart';
import 'package:flutter_x/features/posts/domain/entities/comment.dart';

import 'comment_fixture.dart';

void main() {
  group('Comment', () {
    test('should compare by every field, so a rebuilt thread is a real change', () {
      expect(
        comment,
        const Comment(
          id: 1,
          postId: 1,
          name: 'Ada Lovelace',
          email: 'ada@example.com',
          body: 'The first comment on the first post.',
        ),
      );
      expect(
        comment,
        isNot(
          const Comment(
            id: 2,
            postId: 1,
            name: 'Ada Lovelace',
            email: 'ada@example.com',
            body: 'The first comment on the first post.',
          ),
        ),
      );
    });

    test('should name itself for a failure message', () {
      expect(comment.toString(), 'Comment(1, Ada Lovelace)');
    });
  });

  group('cleanedCommentName', () {
    test('should trim what the form collected', () {
      expect(cleanedCommentName('  Ada Lovelace  '), 'Ada Lovelace');
    });

    test('should reject a comment with no name', () {
      expect(
        () => cleanedCommentName('   '),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.fieldErrors['name'],
            'fieldErrors[name]',
            'A comment needs a name.',
          ),
        ),
      );
    });
  });

  group('cleanedCommentEmail', () {
    test('should trim what the form collected', () {
      expect(cleanedCommentEmail('  ada@example.com  '), 'ada@example.com');
    });

    test('should reject a comment with no email address', () {
      expect(
        () => cleanedCommentEmail('   '),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.fieldErrors['email'],
            'fieldErrors[email]',
            'A comment needs an email address.',
          ),
        ),
      );
    });

    test('should reject an address with no @', () {
      expect(
        () => cleanedCommentEmail('ada.example.com'),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.fieldErrors['email'],
            'fieldErrors[email]',
            'Enter an email address like ada@example.com.',
          ),
        ),
      );
    });
  });

  group('cleanedCommentBody', () {
    test('should trim what the form collected', () {
      expect(cleanedCommentBody('  A comment  '), 'A comment');
    });

    test('should reject a comment with no body', () {
      expect(
        () => cleanedCommentBody('   '),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.fieldErrors['body'],
            'fieldErrors[body]',
            'A comment needs a body.',
          ),
        ),
      );
    });
  });
}
