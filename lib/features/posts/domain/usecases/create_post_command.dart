import 'package:cqrs/cqrs.dart';
import 'package:injectify/injectify.dart';

import '../entities/post.dart';
import '../repositories/post_repository.dart';

// Writes a new post.
class CreatePostCommand extends Command<Post> {
  const CreatePostCommand({
    required this.userId,
    required this.title,
    required this.body,
  });

  final int userId;
  final String title;
  final String body;
}

// The write side: apply the rule the UI cannot be trusted with, then let the
// store assign the id and answer with what it recorded.
//
// `async` on purpose: a bad command has to arrive as a failed future, not as a
// synchronous throw out of `dispatcher.command(...)`.
@Injectable(scope: Scope.factory)
class CreatePostCommandHandler
    implements CommandHandler<CreatePostCommand, Post> {
  const CreatePostCommandHandler(this._posts);

  final PostRepository _posts;

  @override
  Future<Post> execute(CreatePostCommand command) async => _posts.createPost(
    userId: command.userId,
    title: cleanedTitle(command.title),
    body: command.body.trim(),
  );
}
