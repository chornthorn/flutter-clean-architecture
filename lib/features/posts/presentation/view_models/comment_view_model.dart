import 'package:injectify/injectify.dart';
import 'package:signals/signals_flutter.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/presentation/action_result.dart';
import '../../../../core/presentation/form/app_form_controller.dart';
import '../../../../core/presentation/view_model.dart';
import '../../domain/entities/comment.dart';
import '../../domain/usecases/create_comment_use_case.dart';
import '../../domain/usecases/get_comments_use_case.dart';
import '../forms/comment_form_field.dart';

// The comments on one post. Scoped to the post detail route, beside the post's
// own view model, so a page that never opens a thread never reads one.
@Injectable(scope: Scope.factory)
class CommentViewModel extends ViewModel {
  CommentViewModel({
    required this._getComments,
    required this._createComment,
  });

  final GetCommentsUseCase _getComments;
  final CreateCommentUseCase _createComment;

  final _comments = asyncSignal<List<Comment>>(AsyncState.loading());

  // Settled, not loading: no write has run yet.
  final _create = asyncSignal<void>(AsyncState.data(null));

  final commentFormController = AppFormController();

  ReadonlySignal<AsyncState<List<Comment>>> get comments => _comments;
  ReadonlySignal<AsyncState<void>> get create => _create;

  void prepareCreate() {
    commentFormController.clearAll();
  }

  Future<void> load(int postId) async {
    _comments.setLoading();

    try {
      final comments = await _getComments(postId, cancellation: cancellation);
      if (!isAlive) return;
      _comments.setValue(comments);
    } catch (error, stackTrace) {
      if (!isAlive || error is CancelledException) return;
      _comments.setError(error, stackTrace);
    }
  }

  Future<ActionResult> createComment(int postId) async {
    final name = _formValue(CommentFormField.name);
    final email = _formValue(CommentFormField.email);
    final body = _formValue(CommentFormField.body);

    _create.setLoading();

    try {
      final created = await _createComment(
        postId: postId,
        name: name,
        email: email,
        body: body,
        cancellation: cancellation,
      );
      if (!isAlive) return const ActionResult.success();
      // jsonplaceholder answers with the comment it recorded and stores
      // nothing, so the thread keeps the echo rather than re-reading a source
      // that has already forgotten it.
      _comments.setValue([...?_comments.value.value, created]);
      _create.setValue(null);
      commentFormController.clearAll();
      return const ActionResult.success('Comment added successfully.');
    } catch (error, stackTrace) {
      // A write the route walked away from is neither a result nor an error: it
      // never reaches the signal the page is no longer watching.
      if (!isAlive || error is CancelledException) {
        return const ActionResult.failure('Could not add comment.');
      }
      _create.setError(error, stackTrace);
      final message = error is AppException
          ? error.message
          : 'Could not add comment.';
      final fieldErrors = error is ValidationException
          ? error.fieldErrors
          : const <String, String>{};
      final result = ActionResult.failure(message, fieldErrors: fieldErrors);
      commentFormController.bind(result);
      return result;
    }
  }

  // `getValue` trims, and answers null only when no field was ever seeded.
  String _formValue(CommentFormField field) =>
      commentFormController.getValue(FormFieldKey(field)) ?? '';

  // The base cancels the scope before this runs, so a response still on its way
  // finds `isAlive` false and the guards above drop it.
  @override
  void onDispose() {
    _comments.dispose();
    _create.dispose();
    commentFormController.dispose();
  }
}
