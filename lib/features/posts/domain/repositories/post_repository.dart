import '../../../../core/async/cancellation.dart';
import '../entities/post.dart';

// What the posts feature needs from its data source.
//
// Every method carries a token, because any request can be dropped; whether a caller
// should drop one is the caller's call. See `core/README.md`.
abstract interface class PostRepository {
  Future<List<Post>> allPosts({Cancellation? cancellation});

  // `null` means the source has no such post.
  Future<Post?> postById(int id, {Cancellation? cancellation});

  // Answers with what the store recorded, the assigned id included.
  Future<Post> createPost({
    required int userId,
    required String title,
    required String body,
    Cancellation? cancellation,
  });

  // Answers with what the store recorded; the author does not change.
  Future<Post> updatePost({
    required int id,
    required String title,
    required String body,
    Cancellation? cancellation,
  });

  // Deleting one that is already gone is not a failure.
  Future<void> deletePost(int id, {Cancellation? cancellation});
}
