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
import '../../domain/usecases/get_posts_query.dart';
import '../forms/post_form_field.dart';

// State for the posts list: one signal per use case, per `docs/architecture.md`.
@Injectable(scope: Scope.factory)
class PostsHomeViewModel implements ViewModel {
  // jsonplaceholder only echoes this back, and the demo has no signed-in user.
  static const _authorId = 1;

  PostsHomeViewModel(this._dispatcher);

  final CqrsDispatcher _dispatcher;
  final _cancellation = CancellationSource();

  bool _isDisposed = false;

  final _posts = asyncSignal<List<Post>>(AsyncState.loading());

  // Settled, not loading: no write has run yet.
  final _create = asyncSignal<void>(AsyncState.data(null));

  /// Form controller managing input values, controllers, signals, and server errors.
  final form = AppFormController();

  ReadonlySignal<AsyncState<List<Post>>> get posts => _posts;
  ReadonlySignal<AsyncState<void>> get create => _create;

  /// Clears form errors and values before composing a new post.
  void prepareCreate() {
    form.clear();
    form.clearValues();
  }

  Future<void> load() async {
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

  // Answers whether it worked, so the form knows whether to close and what to report.
  // Reads directly from [form] if title and body are not explicitly passed.
  Future<ActionResult> createPost({String? title, String? body}) async {
    final effectiveTitle =
        (title ?? form.text(const FormFieldKey(PostFormField.title))).trim();
    final effectiveBody =
        (body ?? form.text(const FormFieldKey(PostFormField.body))).trim();

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
      form.clear();
      form.clearValues();
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
      form.bind(result);
      return result;
    }
  }

  // The provider calls this when the page unmounts. A disposed signal throws on a
  // write, which is what the guards above are for.
  @override
  void dispose() {
    _isDisposed = true;
    _cancellation.cancel();
    _posts.dispose();
    _create.dispose();
    form.dispose();
  }
}
