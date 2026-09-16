import '../entities/post.dart';

// What the posts feature needs from its data source. Implemented twice: once over
// HTTP and once in memory, so the feature runs with or without a network.
abstract interface class PostRepository {
  Future<List<Post>> allPosts();

  // `null` when the source has no such post.
  Future<Post?> postById(int id);
}
