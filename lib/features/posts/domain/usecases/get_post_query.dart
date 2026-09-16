import 'package:cqrs/cqrs.dart';
import 'package:injectify/injectify.dart';

import '../entities/post.dart';
import '../repositories/post_repository.dart';

// Reads one post by id. An unknown id is a normal outcome, not a failure.
class GetPostQuery extends Query<Post?> {
  const GetPostQuery(this.id);

  final int id;
}

@Injectable(scope: Scope.factory)
class GetPostQueryHandler implements QueryHandler<GetPostQuery, Post?> {
  const GetPostQueryHandler(this._repository);

  final PostRepository _repository;

  @override
  Future<Post?> execute(GetPostQuery query) => _repository.postById(query.id);
}
