import 'package:injectify/injectify.dart';

import '../../../../core/async/cancellation.dart';
import '../../domain/entities/post.dart';
import '../../domain/repositories/post_repository.dart';

// The local adapter: an in-memory store that really keeps what it is given.
@Environment(Environment.dev)
@Environment(Environment.test)
@Injectable(as: PostRepository, scope: Scope.lazySingleton)
class InMemoryPostRepository implements PostRepository {
  final List<Post> _posts = [
    const Post(
      id: 1,
      userId: 1,
      title: 'First post',
      body: 'The first post in the local fixture.',
    ),
    const Post(
      id: 2,
      userId: 1,
      title: 'Second post',
      body: 'The second post in the local fixture.',
    ),
    const Post(
      id: 3,
      userId: 2,
      title: 'Third post',
      body: 'The third post in the local fixture.',
    ),
  ];

  // Nothing is ever in flight here, so the token is taken to honour the contract and ignored.
  @override
  Future<List<Post>> allPosts({Cancellation? cancellation}) async =>
      List.unmodifiable(_posts);

  @override
  Future<Post?> postById(int id, {Cancellation? cancellation}) async {
    for (final post in _posts) {
      if (post.id == id) return post;
    }
    return null;
  }

  @override
  Future<Post> createPost({
    required int userId,
    required String title,
    required String body,
    Cancellation? cancellation,
  }) async {
    final created = Post(
      id: _nextId(),
      userId: userId,
      title: title,
      body: body,
    );
    _posts.add(created);
    return created;
  }

  int _nextId() {
    var highest = 0;
    for (final post in _posts) {
      if (post.id > highest) highest = post.id;
    }
    return highest + 1;
  }

  @override
  Future<Post> updatePost({
    required int id,
    required String title,
    required String body,
    Cancellation? cancellation,
  }) async {
    final index = _posts.indexWhere((post) => post.id == id);

    // Editing a post that is not there is a caller error, not a silent no-op.
    if (index == -1) {
      throw ArgumentError.value(id, 'id', 'No post with that id');
    }

    // The author is carried over: an edit does not reassign the post.
    final updated = Post(
      id: id,
      userId: _posts[index].userId,
      title: title,
      body: body,
    );
    _posts[index] = updated;
    return updated;
  }

  @override
  Future<void> deletePost(int id, {Cancellation? cancellation}) async {
    _posts.removeWhere((post) => post.id == id);
  }
}
