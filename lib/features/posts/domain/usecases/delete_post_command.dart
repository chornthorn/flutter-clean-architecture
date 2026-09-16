import 'package:cqrs/cqrs.dart';
import 'package:injectify/injectify.dart';

import '../repositories/post_repository.dart';

// Removes a post.
class DeletePostCommand extends Command<void> {
  const DeletePostCommand(this.id);

  final int id;
}

// Nothing to decide here: the contract already says that removing what is gone is
// the same as removing what is there.
@Injectable(scope: Scope.factory)
class DeletePostCommandHandler
    implements CommandHandler<DeletePostCommand, void> {
  const DeletePostCommandHandler(this._posts);

  final PostRepository _posts;

  @override
  Future<void> execute(DeletePostCommand command) =>
      _posts.deletePost(command.id);
}
