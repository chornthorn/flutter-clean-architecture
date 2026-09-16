import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';

import '../dtos/post_dto.dart';

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
}
