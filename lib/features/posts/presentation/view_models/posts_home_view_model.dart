import 'package:cqrs/cqrs.dart';
import 'package:injectify/injectify.dart';
import 'package:signals/signals_flutter.dart';

import '../../../../core/async/cancellation.dart';
import '../../../../core/presentation/view_model.dart';
import '../../domain/entities/post.dart';
import '../../domain/usecases/create_post_command.dart';
import '../../domain/usecases/get_posts_query.dart';

// State for the posts list. Factory-scoped: one per page, disposed by the
// `Provider` that created it.
//
// One `AsyncSignal` per use case, each published as a `ReadonlySignal`. See
// `docs/architecture.md`.
@Injectable(scope: Scope.factory)
class PostsHomeViewModel implements ViewModel {
  PostsHomeViewModel(this._dispatcher);

  // The demo has no signed-in user, and jsonplaceholder only echoes this back.
  static const _authorId = 1;

  final CqrsDispatcher _dispatcher;

  // The page's way out of its own reads. Disposal *is* the page going away —
  // the provider disposes this view model when it unmounts — so a read still in
  // flight is dropped there instead of finishing into a screen nobody is
  // watching.
  final _cancellation = CancellationSource();

  bool _isDisposed = false;

  // `GetPostsQuery`. Loading until the read settles, and the list after that.
  final _posts = asyncSignal<List<Post>>(AsyncState.loading());

  // `CreatePostCommand`. Carries no payload: reaching `AsyncData` is the write
  // landing and `AsyncError` is it failing. Settled rather than loading, because
  // no write has run yet.
  final _create = asyncSignal<void>(AsyncState.data(null));

  // What the screen is showing: the list, a list that has not arrived, or a read
  // that failed.
  ReadonlySignal<AsyncState<List<Post>>> get posts => _posts;

  // The last create's attempt, for as long as it is worth reporting.
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
      // A dropped read is not a failure: there is nobody left to report it to.
      // Everything else is.
      if (_isDisposed) return;
      _posts.setError(error, stackTrace);
    }
  }

  // Sends the command, then re-reads the list rather than inserting locally.
  // Answers whether it worked, so the form knows whether to close.
  //
  // No cancellation goes with the command, though the contract would carry one:
  // once a write is on the wire, what happened is the server's to decide, and
  // dropping it would leave the app and the server disagreeing. The re-read that
  // follows does take the token — it is the read this page can afford to lose.
  Future<bool> createPost({required String title, required String body}) async {
    _create.setLoading();

    try {
      await _dispatcher.command(
        CreatePostCommand(userId: _authorId, title: title, body: body),
      );
      final posts = await _dispatcher.query(
        GetPostsQuery(cancellation: _cancellation.token),
      );
      // The write landed either way, so this answers true; the signal is what
      // stays silent once the page is gone.
      if (_isDisposed) return true;
      _posts.setValue(posts);
      _create.setValue(null);
      return true;
    } catch (error, stackTrace) {
      // The re-read can be dropped on the way out. The write itself already
      // landed, and there is nobody left to be told either way — so this
      // answers the conservative thing rather than the true one.
      if (_isDisposed) return false;
      // The failure is the write's, so it stays off the list's own state: a
      // create that failed leaves what is on screen alone.
      _create.setError(error, stackTrace);
      return false;
    }
  }

  // Walking away: the provider above the page calls this when the route unmounts.
  //
  // The flag comes first and the cancellation second, so a read the cancellation
  // drops finds the view model already closed and writes nothing back. A signal
  // that has been disposed *throws* on a write, which is why every write above
  // checks the flag first.
  @override
  void dispose() {
    _isDisposed = true;
    _cancellation.cancel();
    _posts.dispose();
    _create.dispose();
  }
}
