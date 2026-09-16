import 'package:cqrs/cqrs.dart';
import 'package:injectify/injectify.dart';

import '../entities/post.dart';
import '../repositories/post_repository.dart';

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

// `async` on purpose: a bad title must fail the future, not throw out of `dispatcher.command(...)`.
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
