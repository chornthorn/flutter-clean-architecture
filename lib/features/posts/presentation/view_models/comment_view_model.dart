import 'package:injectify/injectify.dart';
import 'package:signals/signals_flutter.dart';

import '../../../../core/error/app_exception.dart';
import '../../../../core/presentation/action_result.dart';
import '../../../../core/presentation/form/app_form_controller.dart';
import '../../../../core/presentation/view_model.dart';
import '../../domain/entities/comment.dart';
import '../../domain/usecases/create_comment_command.dart';
import '../../domain/usecases/get_comments_query.dart';
import '../forms/comment_form_field.dart';

// The comments on one post. Scoped to the post detail route, beside the post's
// own view model, so a page that never opens a thread never reads one.
@Injectable(scope: Scope.factory)
class CommentViewModel extends ViewModel {
  CommentViewModel({required super.dispatcher, required super.context});

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
      final comments = await context.run(
        () => dispatcher.query(
          GetCommentsQuery(postId, cancellation: context.cancellation),
        ),
        args: [postId],
      );
      if (context.isCancelled) return;
      _comments.setValue(comments);
    } catch (error, stackTrace) {
      if (context.isCancelled || error is CancelledException) return;
      _comments.setError(error, stackTrace);
    }
  }

  Future<ActionResult> createComment(int postId) => context.run(() async {
    final name = _formValue(CommentFormField.name);
    final email = _formValue(CommentFormField.email);
    final body = _formValue(CommentFormField.body);

    _create.setLoading();

    try {
      final created = await dispatcher.command(
        CreateCommentCommand(
          postId: postId,
          name: name,
          email: email,
          body: body,
        ),
      );
      if (context.isCancelled) return const ActionResult.success();
      // jsonplaceholder answers with the comment it recorded and stores
      // nothing, so the thread keeps the echo rather than re-reading a source
      // that has already forgotten it.
      _comments.setValue([...?_comments.value.value, created]);
      _create.setValue(null);
      commentFormController.clearAll();
      return const ActionResult.success('Comment added successfully.');
    } catch (error, stackTrace) {
      // This body swallows the error, so the capture has to be told.
      if (error is AppException) context.fail(error);

      if (context.isCancelled) {
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
  }, args: [postId]);

  // `getValue` trims, and answers null only when no field was ever seeded.
  String _formValue(CommentFormField field) =>
      commentFormController.getValue(FormFieldKey(field)) ?? '';

  // The provider calls this when the page unmounts. A disposed signal throws on a
  // write, which is what the guards above are for.
  @override
  void dispose() {
    super.dispose();
    _comments.dispose();
    _create.dispose();
    commentFormController.dispose();
  }
}
