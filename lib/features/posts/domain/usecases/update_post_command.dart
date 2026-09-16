import 'package:cqrs/cqrs.dart';
import 'package:injectify/injectify.dart';

import '../entities/post.dart';
import '../repositories/post_repository.dart';

// Edits an existing post.
class UpdatePostCommand extends Command<Post> {
  const UpdatePostCommand({
    required this.id,
    required this.title,
    required this.body,
  });

  final int id;
  final String title;
  final String body;
}

// The same rule as create, from the same place: `cleanedTitle` is what stops the
// two write paths from drifting apart.
@Injectable(scope: Scope.factory)
class UpdatePostCommandHandler
    implements CommandHandler<UpdatePostCommand, Post> {
  const UpdatePostCommandHandler(this._posts);

  final PostRepository _posts;

  @override
  Future<Post> execute(UpdatePostCommand command) async => _posts.updatePost(
    id: command.id,
    title: cleanedTitle(command.title),
    body: command.body.trim(),
  );
}
