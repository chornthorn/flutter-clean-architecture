import '../../../../core/async/cancellation.dart';
import '../entities/post.dart';

// What the posts feature needs from its data source. Implemented twice: once over
// HTTP and once in memory, so the feature runs with or without a network.
//
// Every method takes a [Cancellation], because every path down to the wire can be
// dropped. Whether a caller *should* drop one is a separate question: a read
// dropped on the way out only wastes an answer nobody would have seen, while a
// write dropped mid-flight may still land on the server — so the shipped callers
// hand a token to reads and let writes finish. See `core/README.md`.
abstract interface class PostRepository {
  Future<List<Post>> allPosts({Cancellation? cancellation});

  // `null` when the source has no such post.
  Future<Post?> postById(int id, {Cancellation? cancellation});

  // Stores a new post and answers with what the store recorded — including the id
  // the store assigned.
  Future<Post> createPost({
    required int userId,
    required String title,
    required String body,
    Cancellation? cancellation,
  });

  // Replaces the title and body of an existing post and answers with what the
  // store recorded. The author does not change.
  Future<Post> updatePost({
    required int id,
    required String title,
    required String body,
    Cancellation? cancellation,
  });

  // Removes a post. Deleting one that is already gone is not a failure.
  Future<void> deletePost(int id, {Cancellation? cancellation});
}
