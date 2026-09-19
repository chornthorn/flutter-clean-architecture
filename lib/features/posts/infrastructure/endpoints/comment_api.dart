import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../dtos/comment_dto.dart';
import '../dtos/create_comment_dto.dart';

part 'comment_api.g.dart';

// The comments endpoints; the implementation is generated into the part file.
@RestApi()
abstract class CommentApi {
  factory CommentApi(Dio dio, {String baseUrl}) = _CommentApi;

  // The comments of one post read under the post they belong to.
  @GET('/posts/{id}/comments')
  Future<List<CommentDto>> commentsForPost(
    @Path('id') int postId, {
    @CancelRequest() CancelToken? cancelToken,
  });

  @POST('/comments')
  Future<CommentDto> createComment(
    @Body() CreateCommentDto comment, {
    @CancelRequest() CancelToken? cancelToken,
  });
}
