import 'package:cqrs/cqrs.dart';
import 'package:injectify/injectify.dart';
import 'package:signals/signals_flutter.dart';

import '../../../../core/async/cancellation.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/presentation/action_result.dart';
import '../../../../core/presentation/form/app_form_controller.dart';
import '../../../../core/presentation/view_model.dart';
import '../../domain/entities/post.dart';
import '../../domain/usecases/create_post_command.dart';
import '../../domain/usecases/delete_post_command.dart';
import '../../domain/usecases/get_post_query.dart';
import '../../domain/usecases/get_posts_query.dart';
import '../../domain/usecases/update_post_command.dart';
import '../forms/post_form_field.dart';

@Injectable(scope: Scope.factory)
class PostViewModel implements ViewModel {
  // jsonplaceholder only echoes this back, and the demo has no signed-in user.
  static const _authorId = 1;

  PostViewModel(this._dispatcher);

  final CqrsDispatcher _dispatcher;
  final _cancellation = CancellationSource();

  bool _isDisposed = false;

  final _posts = asyncSignal<List<Post>>(AsyncState.loading());
  final _post = asyncSignal<Post?>(AsyncState.loading());

  // Settled, not loading: no write has run yet.
  final _create = asyncSignal<void>(AsyncState.data(null));
  final _update = asyncSignal<void>(AsyncState.data(null));
  final _delete = asyncSignal<void>(AsyncState.data(null));

  final createFormController = AppFormController();
  final updateFormController = AppFormController();

  ReadonlySignal<AsyncState<List<Post>>> get posts => _posts;
  ReadonlySignal<AsyncState<Post?>> get post => _post;
  ReadonlySignal<AsyncState<void>> get create => _create;
  ReadonlySignal<AsyncState<void>> get update => _update;
  ReadonlySignal<AsyncState<void>> get delete => _delete;

  void prepareCreate() {
    createFormController.clearAll();
  }

  void prepareEdit(Post post) {
    updateFormController.clearAll();
    updateFormController.setValues({
      PostFormField.title: post.title,
      PostFormField.body: post.body,
    });
  }

  Future<void> load([int? id]) async {
    if (id == null) {
      await loadPosts();
    } else {
      await loadPost(id);
    }
  }

  Future<void> loadPosts() async {
    _posts.setLoading();

    try {
      final posts = await _dispatcher.query(
        GetPostsQuery(cancellation: _cancellation.token),
      );
      if (_isDisposed) return;
      _posts.setValue(posts);
    } catch (error, stackTrace) {
      if (_isDisposed || error is CancelledException) return;
      _posts.setError(error, stackTrace);
    }
  }

  Future<void> loadPost(int id) async {
    _post.setLoading();

    try {
      final post = await _dispatcher.query(
        GetPostQuery(id, cancellation: _cancellation.token),
      );
      if (_isDisposed) return;
      _post.setValue(post);
    } catch (error, stackTrace) {
      if (_isDisposed || error is CancelledException) return;
      _post.setError(error, stackTrace);
    }
  }

  Future<ActionResult> createPost({String? title, String? body}) async {
    final effectiveTitle =
        (title ?? createFormController.text(const FormFieldKey(PostFormField.title))).trim();
    final effectiveBody =
        (body ?? createFormController.text(const FormFieldKey(PostFormField.body))).trim();

    _create.setLoading();

    try {
      await _dispatcher.command(
        CreatePostCommand(
          userId: _authorId,
          title: effectiveTitle,
          body: effectiveBody,
        ),
      );
      final posts = await _dispatcher.query(
        GetPostsQuery(cancellation: _cancellation.token),
      );
      if (_isDisposed) return const ActionResult.success();
      _posts.setValue(posts);
      _create.setValue(null);
      createFormController.clearAll();
      return const ActionResult.success('Post created successfully.');
    } catch (error, stackTrace) {
      if (_isDisposed) {
        return const ActionResult.failure('Could not create post.');
      }
      _create.setError(error, stackTrace);
      final message = error is AppException
          ? error.message
          : 'Could not create post.';
      final fieldErrors = error is ValidationException
          ? error.fieldErrors
          : const <String, String>{};
      final result = ActionResult.failure(message, fieldErrors: fieldErrors);
      createFormController.bind(result);
      return result;
    }
  }

  Future<ActionResult> updatePost(int id, {String? title, String? body}) async {
    final effectiveTitle =
        (title ?? updateFormController.text(const FormFieldKey(PostFormField.title))).trim();
    final effectiveBody =
        (body ?? updateFormController.text(const FormFieldKey(PostFormField.body))).trim();

    _update.setLoading();

    try {
      await _dispatcher.command(
        UpdatePostCommand(id: id, title: effectiveTitle, body: effectiveBody),
      );
      final updated = await _dispatcher.query(
        GetPostQuery(id, cancellation: _cancellation.token),
      );
      if (_isDisposed) return const ActionResult.success();
      _post.setValue(updated);
      _update.setValue(null);
      updateFormController.clear();
      return const ActionResult.success('Post updated successfully.');
    } catch (error, stackTrace) {
      if (_isDisposed) {
        return const ActionResult.failure('Could not update post.');
      }
      _update.setError(error, stackTrace);
      final message = error is AppException
          ? error.message
          : 'Could not update post.';
      final fieldErrors = error is ValidationException
          ? error.fieldErrors
          : const <String, String>{};
      final result = ActionResult.failure(message, fieldErrors: fieldErrors);
      updateFormController.bind(result);
      return result;
    }
  }

  Future<ActionResult> deletePost(int id) async {
    _delete.setLoading();

    try {
      await _dispatcher.command(DeletePostCommand(id));
      if (_isDisposed) return const ActionResult.success();
      _delete.setValue(null);
      return const ActionResult.success('Post deleted successfully.');
    } catch (error, stackTrace) {
      if (_isDisposed) {
        return const ActionResult.failure('Could not delete post.');
      }
      _delete.setError(error, stackTrace);
      final message = error is AppException
          ? error.message
          : 'Could not delete post.';
      return ActionResult.failure(message);
    }
  }

  // The provider calls this when the page unmounts. A disposed signal throws on a
  // write, which is what the guards above are for.
  @override
  void dispose() {
    _isDisposed = true;
    _cancellation.cancel();
    _posts.dispose();
    _post.dispose();
    _create.dispose();
    _update.dispose();
    _delete.dispose();
    createFormController.dispose();
    updateFormController.dispose();
  }
}
