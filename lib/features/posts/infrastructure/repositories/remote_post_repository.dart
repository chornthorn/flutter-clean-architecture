import 'package:dio/dio.dart';
import 'package:injectify/injectify.dart';

import '../../domain/entities/post.dart';
import '../../domain/repositories/post_repository.dart';
import '../endpoints/post_api.dart';

// Talks to jsonplaceholder over HTTP. Wired in `prod`, where the app has a
// network; `dev` and `test` get the in-memory adapter instead.
@Environment(Environment.prod)
@Injectable(as: PostRepository, scope: Scope.lazySingleton)
class RemotePostRepository implements PostRepository {
  RemotePostRepository(Dio dio) : _api = PostApi(dio);

  final PostApi _api;

  @override
  Future<List<Post>> allPosts() async {
    final posts = await _api.allPosts();
    return [for (final post in posts) post.toDomain()];
  }

  @override
  Future<Post?> postById(int id) async {
    try {
      return (await _api.postById(id)).toDomain();
    } on DioException catch (error) {
      // The contract's "no such post" is the API's 404. Anything else is a real
      // failure and belongs to the caller.
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }
}
