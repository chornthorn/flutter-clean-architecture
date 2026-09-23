import 'package:injectify/injectify.dart';

import '../../../../core/async/cancellation.dart';
import '../entities/comment.dart';
import '../repositories/comment_repository.dart';

/// Reads the thread on one post.
@Injectable(scope: Scope.factory)
class GetCommentsUseCase {
  const GetCommentsUseCase(this._comments);

  final CommentRepository _comments;

  // The token is the reader's, handed down so the read is dropped with the
  // screen that asked for it.
  Future<List<Comment>> call(int postId, {Cancellation? cancellation}) =>
      _comments.commentsForPost(postId, cancellation: cancellation);
}
