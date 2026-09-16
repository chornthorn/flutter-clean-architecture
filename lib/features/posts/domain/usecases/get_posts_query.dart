import 'package:cqrs/cqrs.dart';
import 'package:injectify/injectify.dart';

import '../../../../core/async/cancellation.dart';
import '../entities/post.dart';
import '../repositories/post_repository.dart';

class GetPostsQuery extends Query<List<Post>> {
  // Completes when the screen that asked has gone away, so the read is dropped with it.
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
