import 'package:cqrs/cqrs.dart';
import 'package:injectify/injectify.dart';
import 'package:signals/signals_flutter.dart';

import '../../../../core/async/cancellation.dart';
import '../../../../core/presentation/view_model.dart';
import '../../domain/entities/post.dart';
import '../../domain/usecases/create_post_command.dart';
import '../../domain/usecases/get_posts_query.dart';

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

  ReadonlySignal<AsyncState<List<Post>>> get posts => _posts;
  ReadonlySignal<AsyncState<void>> get create => _create;

  Future<void> load() async {
    _posts.setLoading();

    try {
      final posts = await _dispatcher.query(
        GetPostsQuery(cancellation: _cancellation.token),
      );
      if (_isDisposed) return;
      _posts.setValue(posts);
    } catch (error, stackTrace) {
      if (_isDisposed) return;
      _posts.setError(error, stackTrace);
    }
  }

  // Answers whether it worked, so the form knows whether to close.
  Future<bool> createPost({required String title, required String body}) async {
    _create.setLoading();

    try {
      await _dispatcher.command(
        CreatePostCommand(userId: _authorId, title: title, body: body),
      );
      final posts = await _dispatcher.query(
        GetPostsQuery(cancellation: _cancellation.token),
      );
      if (_isDisposed) return true;
      _posts.setValue(posts);
      _create.setValue(null);
      return true;
    } catch (error, stackTrace) {
      if (_isDisposed) return false;
      _create.setError(error, stackTrace);
      return false;
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
  }
}
