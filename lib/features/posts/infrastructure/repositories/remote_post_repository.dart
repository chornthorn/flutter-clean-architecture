import 'package:dio/dio.dart';
import 'package:injectify/injectify.dart';

import '../../../../core/async/cancellation.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/networking/repository.dart';
import '../../domain/entities/post.dart';
import '../../domain/repositories/post_repository.dart';
import '../dtos/create_post_dto.dart';
import '../dtos/update_post_dto.dart';
import '../endpoints/post_api.dart';

// The HTTP adapter. jsonplaceholder stores nothing it is sent — see `lib/features/README.md`.
@Environment(Environment.prod)
@Injectable(as: PostRepository, scope: Scope.lazySingleton)
class RemotePostRepository extends Repository implements PostRepository {
  RemotePostRepository(Dio dio) : _api = PostApi(dio);

  final PostApi _api;

  @override
  Future<List<Post>> allPosts({Cancellation? cancellation}) async {
    final posts = await execute(
      (token) => _api.allPosts(cancelToken: token),
      cancellation: cancellation,
    );
    return [for (final post in posts) post.toDomain()];
  }

  @override
  Future<Post?> postById(int id, {Cancellation? cancellation}) async {
    try {
      final post = await execute(
        (token) => _api.postById(id, cancelToken: token),
        cancellation: cancellation,
      );
      return post.toDomain();
    } on NotFoundException {
      // The contract's "no such post" is 404; anything else is a failure.
      return null;
    }
  }

  @override
  Future<Post> createPost({
    required int userId,
    required String title,
    required String body,
    Cancellation? cancellation,
  }) async {
    final created = await execute(
      (token) => _api.createPost(
        CreatePostDto(userId: userId, title: title, body: body),
        cancelToken: token,
      ),
      cancellation: cancellation,
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
    final updated = await execute(
      (token) => _api.updatePost(
        id,
        UpdatePostDto(title: title, body: body),
        cancelToken: token,
      ),
      cancellation: cancellation,
    );
    return updated.toDomain();
  }

  @override
  Future<void> deletePost(int id, {Cancellation? cancellation}) async {
    try {
      await execute(
        (token) => _api.deletePost(id, cancelToken: token),
        cancellation: cancellation,
      );
    } on NotFoundException {
      // Already gone is the outcome the caller asked for.
      return;
    }
  }
}
