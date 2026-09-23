import 'package:injectify/injectify.dart';

import '../../../../core/async/cancellation.dart';
import '../entities/post.dart';
import '../repositories/post_repository.dart';

/// Reads the whole catalog.
@Injectable(scope: Scope.factory)
class GetPostsUseCase {
  const GetPostsUseCase(this._posts);

  final PostRepository _posts;

  // The token is the reader's, handed down so the read is dropped with the
  // screen that asked for it.
  Future<List<Post>> call({Cancellation? cancellation}) =>
      _posts.allPosts(cancellation: cancellation);
}
