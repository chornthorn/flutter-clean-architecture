import '../../../../core/async/cancellation.dart';
import '../entities/comment.dart';

// What the posts feature needs from the comments behind a post.
//
// Every method carries a token, because any request can be dropped; whether a
// caller should drop one is the caller's call. See `core/README.md`.
abstract interface class CommentRepository {
  // Every comment on one post, in the order the source returns them. A post
  // with no comments answers an empty list, not a failure.
  Future<List<Comment>> commentsForPost(
    int postId, {
    Cancellation? cancellation,
  });

  // Answers with what the store recorded, the assigned id included.
  Future<Comment> createComment({
    required int postId,
    required String name,
    required String email,
    required String body,
    Cancellation? cancellation,
  });
}
