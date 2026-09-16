import 'package:cqrs/cqrs.dart';
import 'package:injectify/injectify.dart';

import '../../../../core/async/cancellation.dart';
import '../entities/post.dart';
import '../repositories/post_repository.dart';

// An unknown id is a normal outcome, not a failure.
class GetPostQuery extends Query<Post?> {
  const GetPostQuery(this.id, {this.cancellation});

  final int id;

  final Cancellation? cancellation;
}

@Injectable(scope: Scope.factory)
class GetPostQueryHandler implements QueryHandler<GetPostQuery, Post?> {
  const GetPostQueryHandler(this._repository);

  final PostRepository _repository;

  @override
  Future<Post?> execute(GetPostQuery query) =>
      _repository.postById(query.id, cancellation: query.cancellation);
}
