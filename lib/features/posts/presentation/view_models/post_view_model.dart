import 'package:injectify/injectify.dart';
import 'package:signals/signals_flutter.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/presentation/action_result.dart';
import '../../../../core/presentation/form/app_form_controller.dart';
import '../../../../core/presentation/view_model.dart';
import '../../domain/entities/post.dart';
import '../../domain/usecases/create_post_use_case.dart';
import '../../domain/usecases/delete_post_use_case.dart';
import '../../domain/usecases/get_post_use_case.dart';
import '../../domain/usecases/get_posts_use_case.dart';
import '../../domain/usecases/update_post_use_case.dart';
import '../forms/post_form_field.dart';

@Injectable(scope: Scope.factory)
class PostViewModel extends ViewModel {
  PostViewModel({
    required this._getPosts,
    required this._getPost,
    required this._createPost,
    required this._updatePost,
    required this._deletePost,
  });

  // The screen's reads and writes, each one the domain's own entry point rather
  // than a message the view model has to name.
  final GetPostsUseCase _getPosts;
  final GetPostUseCase _getPost;
  final CreatePostUseCase _createPost;
  final UpdatePostUseCase _updatePost;
  final DeletePostUseCase _deletePost;

  // jsonplaceholder only echoes this back, and the demo has no signed-in user.
  static const _authorId = 1;

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
      final posts = await _getPosts(cancellation: cancellation);
      if (!isAlive) return;
      _posts.setValue(posts);
    } catch (error, stackTrace) {
      if (!isAlive || error is CancelledException) return;
      _posts.setError(error, stackTrace);
    }
  }

  Future<void> loadPost(int id) async {
    _post.setLoading();

    try {
      final post = await _getPost(id, cancellation: cancellation);
      if (!isAlive) return;
      _post.setValue(post);
    } catch (error, stackTrace) {
      if (!isAlive || error is CancelledException) return;
      _post.setError(error, stackTrace);
    }
  }

  // The form controller is the one source of truth for what the user typed,
  // so the view only has to say "submit".
  Future<ActionResult> createPost() async {
    final title = _formValue(createFormController, PostFormField.title);
    final body = _formValue(createFormController, PostFormField.body);

    _create.setLoading();

    try {
      await _createPost(
        userId: _authorId,
        title: title,
        body: body,
        cancellation: cancellation,
      );
      final posts = await _getPosts(cancellation: cancellation);
      if (!isAlive) return const ActionResult.success();
      _posts.setValue(posts);
      _create.setValue(null);
      createFormController.clearAll();
      return const ActionResult.success('Post created successfully.');
    } catch (error, stackTrace) {
      // A write the route walked away from is neither a result nor an error: it
      // never reaches the signal the page is no longer watching.
      if (!isAlive || error is CancelledException) {
        return const ActionResult.failure('Could not create post.');
      }
      _create.setError(error, stackTrace);
      final message = error is AppException ? error.message : 'Could not create post.';
      final fieldErrors = error is ValidationException
          ? error.fieldErrors
          : const <String, String>{};
      final result = ActionResult.failure(message, fieldErrors: fieldErrors);
      createFormController.bind(result);
      return result;
    }
  }

  Future<ActionResult> updatePost(int id) async {
    final title = _formValue(updateFormController, PostFormField.title);
    final body = _formValue(updateFormController, PostFormField.body);

    _update.setLoading();

    try {
      await _updatePost(
        id: id,
        title: title,
        body: body,
        cancellation: cancellation,
      );
      final updated = await _getPost(id, cancellation: cancellation);
      if (!isAlive) return const ActionResult.success();
      _post.setValue(updated);
      _update.setValue(null);
      updateFormController.clear();
      return const ActionResult.success('Post updated successfully.');
    } catch (error, stackTrace) {
      // A write the route walked away from is neither a result nor an error: it
      // never reaches the signal the page is no longer watching.
      if (!isAlive || error is CancelledException) {
        return const ActionResult.failure('Could not update post.');
      }
      _update.setError(error, stackTrace);
      final message = error is AppException ? error.message : 'Could not update post.';
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
      await _deletePost(id, cancellation: cancellation);
      if (!isAlive) return const ActionResult.success();
      _delete.setValue(null);
      return const ActionResult.success('Post deleted successfully.');
    } catch (error, stackTrace) {
      // A write the route walked away from is neither a result nor an error: it
      // never reaches the signal the page is no longer watching.
      if (!isAlive || error is CancelledException) {
        return const ActionResult.failure('Could not delete post.');
      }
      _delete.setError(error, stackTrace);
      final message = error is AppException ? error.message : 'Could not delete post.';
      return ActionResult.failure(message);
    }
  }

  // `getValue` trims, and answers null only when no field was ever seeded.
  String _formValue(AppFormController controller, PostFormField field) =>
      controller.getValue(FormFieldKey(field)) ?? '';

  // The base cancels the scope before this runs, so a response still on its way
  // finds `isAlive` false and the guards above drop it.
  @override
  void onDispose() {
    _posts.dispose();
    _post.dispose();
    _create.dispose();
    _update.dispose();
    _delete.dispose();
    createFormController.dispose();
    updateFormController.dispose();
  }
}
