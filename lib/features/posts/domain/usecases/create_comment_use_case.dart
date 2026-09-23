import 'package:injectify/injectify.dart';

import '../entities/comment.dart';
import '../repositories/comment_repository.dart';

/// Adds one comment to the thread on a post.
@Injectable(scope: Scope.factory)
class CreateCommentUseCase {
  const CreateCommentUseCase(this._comments);

  final CommentRepository _comments;

  // `async` on purpose: a bad field must fail the future, not throw out of the
  // call the view model is awaiting.
  Future<Comment> call({
    required int postId,
    required String name,
    required String email,
    required String body,
  }) async => _comments.createComment(
    postId: postId,
    name: cleanedCommentName(name),
    email: cleanedCommentEmail(email),
    body: cleanedCommentBody(body),
  );
}
