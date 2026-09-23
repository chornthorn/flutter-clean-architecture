import 'package:injectify/injectify.dart';

import '../../../../core/async/cancellation.dart';
import '../entities/post.dart';
import '../repositories/post_repository.dart';

/// Rewrites the title and body of one post.
@Injectable(scope: Scope.factory)
class UpdatePostUseCase {
  const UpdatePostUseCase(this._posts);

  final PostRepository _posts;

  // The same title rule as create, from the same place: `cleanedTitle`.
  Future<Post> call({
    required int id,
    required String title,
    required String body,
    Cancellation? cancellation,
  }) async => _posts.updatePost(
    id: id,
    title: cleanedTitle(title),
    body: body.trim(),
    cancellation: cancellation,
  );
}
