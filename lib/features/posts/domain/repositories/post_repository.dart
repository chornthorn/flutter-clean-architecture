import '../entities/post.dart';

// What the posts feature needs from its data source. Implemented twice: once over
// HTTP and once in memory, so the feature runs with or without a network.
abstract interface class PostRepository {
  Future<List<Post>> allPosts();

  // `null` when the source has no such post.
  Future<Post?> postById(int id);

  // Stores a new post and answers with what the store recorded — including the id
  // the store assigned.
  Future<Post> createPost({
    required int userId,
    required String title,
    required String body,
  });

  // Replaces the title and body of an existing post and answers with what the
  // store recorded. The author does not change.
  Future<Post> updatePost({
    required int id,
    required String title,
    required String body,
  });

  // Removes a post. Deleting one that is already gone is not a failure.
  Future<void> deletePost(int id);
}
