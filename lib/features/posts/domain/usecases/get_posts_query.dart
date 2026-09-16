import 'package:cqrs/cqrs.dart';
import 'package:injectify/injectify.dart';

import '../entities/post.dart';
import '../repositories/post_repository.dart';

// Lists the posts.
class GetPostsQuery extends Query<List<Post>> {
  const GetPostsQuery();
}

@Injectable(scope: Scope.factory)
class GetPostsQueryHandler implements QueryHandler<GetPostsQuery, List<Post>> {
  const GetPostsQueryHandler(this._repository);

  final PostRepository _repository;

  @override
  Future<List<Post>> execute(GetPostsQuery query) => _repository.allPosts();
}
