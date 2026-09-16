import 'package:dio/dio.dart';
import 'package:injectify/injectify.dart';

import '../../domain/entities/post.dart';
import '../../domain/repositories/post_repository.dart';
import '../dtos/create_post_dto.dart';
import '../dtos/update_post_dto.dart';
import '../endpoints/post_api.dart';

// Talks to jsonplaceholder over HTTP. Wired in `prod`, where the app has a
// network; `dev` and `test` get the in-memory adapter instead.
//
// Note what the API does *not* do: it echoes a created post back with an id of
// its own invention and stores nothing, so a later read will not find it. A real
// backend would persist, and re-reading the list is what a real one rewards.
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

  @override
  Future<Post> createPost({
    required int userId,
    required String title,
    required String body,
  }) async {
    final created = await _api.createPost(
      CreatePostDto(userId: userId, title: title, body: body),
    );
    return created.toDomain();
  }

  @override
  Future<Post> updatePost({
    required int id,
    required String title,
    required String body,
  }) async {
    final updated = await _api.updatePost(
      id,
      UpdatePostDto(title: title, body: body),
    );
    return updated.toDomain();
  }

  @override
  Future<void> deletePost(int id) async {
    try {
      await _api.deletePost(id);
    } on DioException catch (error) {
      // Already gone is the outcome the caller asked for.
      if (error.response?.statusCode == 404) return;
      rethrow;
    }
  }
}
