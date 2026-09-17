import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/posts/domain/usecases/delete_post_command.dart';
import 'package:mocktail/mocktail.dart';

import '../repositories/mock_post_repository.dart';

void main() {
  group('DeletePostCommandHandler', () {
    test('should ask the store to remove the post the command names', () async {
      final posts = MockPostRepository();
      when(() => posts.deletePost(3)).thenAnswer((_) async {});

      await DeletePostCommandHandler(posts).execute(const DeletePostCommand(3));

      verify(() => posts.deletePost(3)).called(1);
    });

    test('should let a store failure escape', () async {
      final posts = MockPostRepository();
      when(() => posts.deletePost(3))
          .thenAnswer((_) async => throw Exception('offline'));

      await expectLater(
        DeletePostCommandHandler(posts).execute(const DeletePostCommand(3)),
        throwsException,
      );
    });
  });
}
