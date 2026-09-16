import 'package:dio/dio.dart';
import 'package:injectify/injectify.dart';

import '../../../../core/async/cancellation.dart';
import '../../domain/entities/post.dart';
import '../../domain/repositories/post_repository.dart';
import '../dtos/create_post_dto.dart';
import '../dtos/update_post_dto.dart';
import '../endpoints/post_api.dart';

// The HTTP adapter. jsonplaceholder stores nothing it is sent — see `lib/features/README.md`.
@Environment(Environment.prod)
@Injectable(as: PostRepository, scope: Scope.lazySingleton)
class RemotePostRepository implements PostRepository {
  RemotePostRepository(Dio dio) : _api = PostApi(dio);

  final PostApi _api;

  @override
  Future<List<Post>> allPosts({Cancellation? cancellation}) async {
    final posts = await _api.allPosts(cancelToken: _tokenFor(cancellation));
    return [for (final post in posts) post.toDomain()];
  }

  @override
  Future<Post?> postById(int id, {Cancellation? cancellation}) async {
    try {
      return (await _api.postById(
        id,
        cancelToken: _tokenFor(cancellation),
      )).toDomain();
    } on DioException catch (error) {
      // The contract's "no such post" is the API's 404; anything else is a real failure.
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<Post> createPost({
    required int userId,
    required String title,
    required String body,
    Cancellation? cancellation,
  }) async {
    final created = await _api.createPost(
      CreatePostDto(userId: userId, title: title, body: body),
      cancelToken: _tokenFor(cancellation),
    );
    return created.toDomain();
  }

  @override
  Future<Post> updatePost({
    required int id,
    required String title,
    required String body,
    Cancellation? cancellation,
  }) async {
    final updated = await _api.updatePost(
      id,
      UpdatePostDto(title: title, body: body),
      cancelToken: _tokenFor(cancellation),
    );
    return updated.toDomain();
  }

  @override
  Future<void> deletePost(int id, {Cancellation? cancellation}) async {
    try {
      await _api.deletePost(id, cancelToken: _tokenFor(cancellation));
    } on DioException catch (error) {
      // Already gone is the outcome the caller asked for.
      if (error.response?.statusCode == 404) return;
      rethrow;
    }
  }

  // `ignore`: the failure a dropped request raises reaches the caller, which is
  // the one that knows it was a cancellation.
  CancelToken? _tokenFor(Cancellation? cancellation) {
    if (cancellation == null) return null;

    final token = CancelToken();
    cancellation.whenComplete(token.cancel).ignore();
    return token;
  }
}
