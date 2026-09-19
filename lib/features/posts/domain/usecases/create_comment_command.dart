import 'package:cqrs/cqrs.dart';
import 'package:injectify/injectify.dart';

import '../entities/comment.dart';
import '../repositories/comment_repository.dart';

class CreateCommentCommand extends Command<Comment> {
  const CreateCommentCommand({
    required this.postId,
    required this.name,
    required this.email,
    required this.body,
  });

  final int postId;
  final String name;
  final String email;
  final String body;
}

// `async` on purpose: a bad field must fail the future, not throw out of `dispatcher.command(...)`.
@Injectable(scope: Scope.factory)
class CreateCommentCommandHandler
    implements CommandHandler<CreateCommentCommand, Comment> {
  const CreateCommentCommandHandler(this._comments);

  final CommentRepository _comments;

  @override
  Future<Comment> execute(CreateCommentCommand command) async {
    return _comments.createComment(
      postId: command.postId,
      name: cleanedCommentName(command.name),
      email: cleanedCommentEmail(command.email),
      body: cleanedCommentBody(command.body),
    );
  }
}
