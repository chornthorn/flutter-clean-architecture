import 'package:injectify/injectify.dart';

import '../../../../core/async/cancellation.dart';
import '../entities/post.dart';
import '../repositories/post_repository.dart';

/// Reads one post by id.
@Injectable(scope: Scope.factory)
class GetPostUseCase {
  const GetPostUseCase(this._posts);

  final PostRepository _posts;

  // An unknown id is a normal outcome, not a failure, so the answer is nullable.
  Future<Post?> call(int id, {Cancellation? cancellation}) =>
      _posts.postById(id, cancellation: cancellation);
}
