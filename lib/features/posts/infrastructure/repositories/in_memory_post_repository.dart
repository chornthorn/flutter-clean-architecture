import 'package:injectify/injectify.dart';

import '../../domain/entities/post.dart';
import '../../domain/repositories/post_repository.dart';

// A local fixture in the same shape the API serves, so the feature runs with no
// network. Deliberately short titles: this is a fixture, not a mirror of the
// remote catalog.
@Environment(Environment.dev)
@Environment(Environment.test)
@Injectable(as: PostRepository, scope: Scope.lazySingleton)
class InMemoryPostRepository implements PostRepository {
  const InMemoryPostRepository();

  static const _posts = <Post>[
    Post(
      id: 1,
      userId: 1,
      title: 'First post',
      body: 'The first post in the local fixture.',
    ),
    Post(
      id: 2,
      userId: 1,
      title: 'Second post',
      body: 'The second post in the local fixture.',
    ),
    Post(
      id: 3,
      userId: 2,
      title: 'Third post',
      body: 'The third post in the local fixture.',
    ),
  ];

  @override
  Future<List<Post>> allPosts() async => _posts;

  @override
  Future<Post?> postById(int id) async {
    for (final post in _posts) {
      if (post.id == id) return post;
    }
    return null;
  }
}
