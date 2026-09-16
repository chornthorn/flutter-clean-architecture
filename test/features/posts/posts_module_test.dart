import 'package:cqrs/cqrs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/posts/domain/repositories/post_repository.dart';
import 'package:flutter_x/features/posts/domain/usecases/get_posts_query.dart';
import 'package:flutter_x/features/posts/infrastructure/repositories/in_memory_post_repository.dart';
import 'package:flutter_x/features/posts/infrastructure/repositories/remote_post_repository.dart';
import 'package:flutter_x/provider.dart';
import 'package:injectify/injectify.dart';

import 'domain/entities/post_fixture.dart';

void main() {
  setUp(() async => getIt.reset());

  // The feature's point is that its source is a choice, not a fact, so which
  // adapter each environment gets is worth pinning — the rest of the suite
  // depends on it, and a wrong binding would only show up as a network call.
  group('PostRepository binding', () {
    test('should read the fixture in dev', () async {
      await configureDependencies(environment: Environment.dev);

      expect(getIt<PostRepository>(), isA<InMemoryPostRepository>());
    });

    test('should read the fixture in test', () async {
      await configureDependencies(environment: Environment.test);

      expect(getIt<PostRepository>(), isA<InMemoryPostRepository>());
    });

    test('should read over HTTP in prod', () async {
      await configureDependencies(environment: Environment.prod);

      expect(getIt<PostRepository>(), isA<RemotePostRepository>());
    });
  });

  test(
    'should serve the list through the container without a network',
    () async {
      await configureDependencies(environment: Environment.test);

      final posts = await getIt<CqrsDispatcher>().query(const GetPostsQuery());

      expect(posts, contains(post));
    },
  );
}
