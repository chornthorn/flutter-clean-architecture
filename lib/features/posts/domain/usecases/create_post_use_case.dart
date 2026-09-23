import 'package:injectify/injectify.dart';

import '../../../../core/async/cancellation.dart';
import '../../../../core/error/app_exception.dart';
import '../entities/post.dart';
import '../repositories/post_repository.dart';

/// Adds one post to the catalog.
@Injectable(scope: Scope.factory)
class CreatePostUseCase {
  const CreatePostUseCase(this._posts);

  final PostRepository _posts;

  // `async` on purpose: a bad title must fail the future, not throw out of the
  // call the view model is awaiting.
  Future<Post> call({
    required int userId,
    required String title,
    required String body,
    Cancellation? cancellation,
  }) async {
    final cleaned = cleanedTitle(title);
    if (cleaned.length < 5) {
      throw const ValidationException(
        message: 'Title must be at least 5 characters.',
        fieldErrors: {'title': 'Title must be at least 5 characters.'},
      );
    }
    return _posts.createPost(
      userId: userId,
      title: cleaned,
      body: body.trim(),
      cancellation: cancellation,
    );
  }
}
