import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../dtos/create_post_dto.dart';
import '../dtos/post_dto.dart';
import '../dtos/update_post_dto.dart';

part 'post_api.g.dart';

// The feature's endpoints, one method per call. The implementation — paths,
// query strings, decoding — is generated into the part file.
@RestApi()
abstract class PostApi {
  factory PostApi(Dio dio, {String baseUrl}) = _PostApi;

  @GET('/posts')
  Future<List<PostDto>> allPosts();

  @GET('/posts/{id}')
  Future<PostDto> postById(@Path('id') int id);

  @POST('/posts')
  Future<PostDto> createPost(@Body() CreatePostDto post);

  // PATCH, not PUT: an edit sends the fields it changes and leaves the rest alone.
  @PATCH('/posts/{id}')
  Future<PostDto> updatePost(@Path('id') int id, @Body() UpdatePostDto post);

  @DELETE('/posts/{id}')
  Future<void> deletePost(@Path('id') int id);
}
