import 'package:injectify/injectify.dart';

import '../repositories/post_repository.dart';

/// Removes one post from the catalog.
@Injectable(scope: Scope.factory)
class DeletePostUseCase {
  const DeletePostUseCase(this._posts);

  final PostRepository _posts;

  // Nothing to decide: the contract already treats removing what is gone as done.
  Future<void> call(int id) => _posts.deletePost(id);
}
