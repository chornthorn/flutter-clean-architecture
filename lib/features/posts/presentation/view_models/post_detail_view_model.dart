import 'package:cqrs/cqrs.dart';
import 'package:injectify/injectify.dart';
import 'package:signals/signals_flutter.dart';

import '../../../../core/async/cancellation.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/presentation/action_result.dart';
import '../../../../core/presentation/form/app_form_controller.dart';
import '../../../../core/presentation/view_model.dart';
import '../../domain/entities/post.dart';
import '../../domain/usecases/delete_post_command.dart';
import '../../domain/usecases/get_post_query.dart';
import '../../domain/usecases/update_post_command.dart';
import '../forms/post_form_field.dart';

// State for the post detail page: one signal per use case, per `docs/architecture.md`.
@Injectable(scope: Scope.factory)
class PostDetailViewModel implements ViewModel {
  PostDetailViewModel(this._dispatcher);

  final CqrsDispatcher _dispatcher;
  final _cancellation = CancellationSource();

  bool _isDisposed = false;

  final _post = asyncSignal<Post?>(AsyncState.loading());

  // Settled, not loading: no write has run yet.
  final _update = asyncSignal<void>(AsyncState.data(null));
  final _delete = asyncSignal<void>(AsyncState.data(null));

  /// Form controller managing input values, controllers, signals, and server error binding.
  final form = AppFormController();

  ReadonlySignal<AsyncState<Post?>> get post => _post;
  ReadonlySignal<AsyncState<void>> get update => _update;
  ReadonlySignal<AsyncState<void>> get delete => _delete;

  /// Pre-populates the form controller with post fields for editing.
  void prepareEdit(Post post) {
    form.clear();
    form.setValues({
      PostFormField.title: post.title,
      PostFormField.body: post.body,
    });
  }

  Future<void> load(int id) async {
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

  // Returns an ActionResult so the view knows whether it worked, what message to
  // alert or toast, and any validation field errors.
  // Reads directly from [form] if title and body are not explicitly passed.
  Future<ActionResult> updatePost(int id, {String? title, String? body}) async {
    final effectiveTitle =
        (title ?? form.text(const FormFieldKey(PostFormField.title))).trim();
    final effectiveBody =
        (body ?? form.text(const FormFieldKey(PostFormField.body))).trim();

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
      form.clear();
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
      form.bind(result);
      return result;
    }
  }

  // Returns an ActionResult so the page knows whether to navigate and show feedback.
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
    _post.dispose();
    _update.dispose();
    _delete.dispose();
    form.dispose();
  }
}
