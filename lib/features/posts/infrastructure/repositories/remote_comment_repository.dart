import 'package:dio/dio.dart';
import 'package:injectify/injectify.dart';

import '../../../../core/async/cancellation.dart';
import '../../../../core/networking/repository.dart';
import '../../domain/entities/comment.dart';
import '../../domain/repositories/comment_repository.dart';
import '../dtos/create_comment_dto.dart';
import '../endpoints/comment_api.dart';

// The HTTP adapter. jsonplaceholder stores nothing it is sent — see `lib/features/README.md`.
@Environment(Environment.prod)
@Injectable(as: CommentRepository, scope: Scope.lazySingleton)
class RemoteCommentRepository extends Repository implements CommentRepository {
  RemoteCommentRepository(Dio dio) : _api = CommentApi(dio);

  final CommentApi _api;

  @override
  Future<List<Comment>> commentsForPost(
    int postId, {
    Cancellation? cancellation,
  }) async {
    final comments = await execute(
      (token) => _api.commentsForPost(postId, cancelToken: token),
      cancellation: cancellation,
    );
    return [for (final comment in comments) comment.toDomain()];
  }

  @override
  Future<Comment> createComment({
    required int postId,
    required String name,
    required String email,
    required String body,
    Cancellation? cancellation,
  }) async {
    final created = await execute(
      (token) => _api.createComment(
        CreateCommentDto(
          postId: postId,
          name: name,
          email: email,
          body: body,
        ),
        cancelToken: token,
      ),
      cancellation: cancellation,
    );
    return created.toDomain();
  }
}
