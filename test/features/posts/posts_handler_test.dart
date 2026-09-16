import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/posts/domain/usecases/get_post_query.dart';
import 'package:flutter_x/features/posts/domain/usecases/get_posts_query.dart';
import 'package:mocktail/mocktail.dart';

import 'domain/entities/post_fixture.dart';
import 'domain/repositories/mock_post_repository.dart';
import 'posts_dispatcher_fixture.dart';

void main() {
  // The generated module is the only thing binding a message to its handler. A
  // message it fails to register throws HandlerNotFoundException at dispatch.
  group('PostsCqrsModule', () {
    late MockPostRepository repository;

    setUp(() {
      repository = MockPostRepository();
      when(() => repository.allPosts()).thenAnswer((_) async => const [post]);
      when(() => repository.postById(1)).thenAnswer((_) async => post);
    });

    test('should dispatch every query the feature declares', () async {
      final dispatcher = postsDispatcher(repository);

      expect(await dispatcher.query(const GetPostsQuery()), const [post]);
      expect(await dispatcher.query(const GetPostQuery(1)), post);
    });
  });
}
