import 'package:cqrs/cqrs.dart';
import 'package:injectify/injectify.dart';

import '../repositories/post_repository.dart';

class DeletePostCommand extends Command<void> {
  const DeletePostCommand(this.id);

  final int id;
}

// Nothing to decide: the contract already treats removing what is gone as done.
@Injectable(scope: Scope.factory)
class DeletePostCommandHandler
    implements CommandHandler<DeletePostCommand, void> {
  const DeletePostCommandHandler(this._posts);

  final PostRepository _posts;

  @override
  Future<void> execute(DeletePostCommand command) =>
      _posts.deletePost(command.id);
}
