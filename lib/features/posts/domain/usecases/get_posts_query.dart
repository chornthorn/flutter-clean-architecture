import 'package:cqrs/cqrs.dart';
import 'package:injectify/injectify.dart';

import '../../../../core/async/cancellation.dart';
import '../entities/post.dart';
import '../repositories/post_repository.dart';

// Lists the posts.
class GetPostsQuery extends Query<List<Post>> {
  // The token completes when the screen that asked has gone away. The handler
  // passes it down, so the read is dropped instead of finishing into a page
  // nobody is watching.
  const GetPostsQuery({this.cancellation});

  final Cancellation? cancellation;
}

@Injectable(scope: Scope.factory)
class GetPostsQueryHandler implements QueryHandler<GetPostsQuery, List<Post>> {
  const GetPostsQueryHandler(this._repository);

  final PostRepository _repository;

  @override
  Future<List<Post>> execute(GetPostsQuery query) =>
      _repository.allPosts(cancellation: query.cancellation);
}
