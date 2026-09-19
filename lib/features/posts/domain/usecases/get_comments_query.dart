import 'package:cqrs/cqrs.dart';
import 'package:injectify/injectify.dart';

import '../../../../core/async/cancellation.dart';
import '../entities/comment.dart';
import '../repositories/comment_repository.dart';

class GetCommentsQuery extends Query<List<Comment>> {
  // Completes when the screen that asked has gone away, so the read is dropped with it.
  const GetCommentsQuery(this.postId, {this.cancellation});

  final int postId;

  final Cancellation? cancellation;
}

@Injectable(scope: Scope.factory)
class GetCommentsQueryHandler
    implements QueryHandler<GetCommentsQuery, List<Comment>> {
  const GetCommentsQueryHandler(this._repository);

  final CommentRepository _repository;

  @override
  Future<List<Comment>> execute(GetCommentsQuery query) =>
      _repository.commentsForPost(
        query.postId,
        cancellation: query.cancellation,
      );
}
