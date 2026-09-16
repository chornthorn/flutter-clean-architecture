import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../dtos/create_post_dto.dart';
import '../dtos/post_dto.dart';
import '../dtos/update_post_dto.dart';

part 'post_api.g.dart';

// The feature's endpoints; the implementation is generated into the part file.
@RestApi()
abstract class PostApi {
  factory PostApi(Dio dio, {String baseUrl}) = _PostApi;

  @GET('/posts')
  Future<List<PostDto>> allPosts({@CancelRequest() CancelToken? cancelToken});

  @GET('/posts/{id}')
  Future<PostDto> postById(
    @Path('id') int id, {
    @CancelRequest() CancelToken? cancelToken,
  });

  @POST('/posts')
  Future<PostDto> createPost(
    @Body() CreatePostDto post, {
    @CancelRequest() CancelToken? cancelToken,
  });

  // PATCH, not PUT: an edit sends the fields it changes and leaves the rest alone.
  @PATCH('/posts/{id}')
  Future<PostDto> updatePost(
    @Path('id') int id,
    @Body() UpdatePostDto post, {
    @CancelRequest() CancelToken? cancelToken,
  });

  @DELETE('/posts/{id}')
  Future<void> deletePost(
    @Path('id') int id, {
    @CancelRequest() CancelToken? cancelToken,
  });
}
