import 'package:cqrs/cqrs.dart';
import 'package:injectify/injectify.dart';
import 'package:signals/signals_flutter.dart';

import '../../../../core/async/cancellation.dart';
import '../../domain/entities/post.dart';
import '../../domain/usecases/delete_post_command.dart';
import '../../domain/usecases/get_post_query.dart';
import '../../domain/usecases/update_post_command.dart';
import '../posts_revision.dart';

// State for one post. Same scope and lifecycle rules as the other view models.
//
// The id is a `load` argument rather than a field: it comes from the route, and
// the page that owns it passes it in.
//
// One `AsyncSignal` per use case, each published as a `ReadonlySignal`. Reading,
// editing and deleting have separate lifecycles, so a failed save cannot put the
// read into an error state. See `docs/architecture.md`.
@Injectable(scope: Scope.factory)
class PostDetailViewModel {
  PostDetailViewModel(this._dispatcher, this._revision);

  final CqrsDispatcher _dispatcher;
  final PostsRevision _revision;

  // See `PostsHomeViewModel`: cancelling in `dispose` is the page walking away
  // from whatever read is still in flight.
  final _cancellation = CancellationSource();

  bool _isDisposed = false;

  // `GetPostQuery`. Loading until the read settles, and the post after that — or
  // `AsyncData(null)` for an id that has none, which is a value and not a
  // failure, and is what tells "not found" apart from "could not load".
  final _post = asyncSignal<Post?>(AsyncState.loading());

  // `UpdatePostCommand`. Carries no payload: reaching `AsyncData` is the edit
  // landing and `AsyncError` is it failing. Settled rather than loading, because
  // no write has run yet.
  final _update = asyncSignal<void>(AsyncState.data(null));

  // `DeletePostCommand`. Shaped like [_update].
  final _delete = asyncSignal<void>(AsyncState.data(null));

  // What the screen is showing: a post, a missing post, a load in flight, or a
  // load that failed.
  ReadonlySignal<AsyncState<Post?>> get post => _post;

  // The last edit's attempt, for as long as it is worth reporting.
  ReadonlySignal<AsyncState<void>> get update => _update;

  // The last delete's attempt.
  ReadonlySignal<AsyncState<void>> get delete => _delete;

  Future<void> load(int id) async {
    _post.setLoading();

    try {
      final post = await _dispatcher.query(
        GetPostQuery(id, cancellation: _cancellation.token),
      );
      if (_isDisposed) return;
      _post.setValue(post);
    } catch (error, stackTrace) {
      // A dropped read is not a failure: there is nobody left to report it to.
      // Everything else is.
      if (_isDisposed) return;
      _post.setError(error, stackTrace);
    }
  }

  // Sends the edit, then re-reads the post rather than patching a local copy.
  // Answers whether it worked, so the form knows whether to close.
  Future<bool> updatePost({required String title, required String body}) async {
    final post = _settledPost;
    if (post == null) return false;

    _update.setLoading();

    try {
      await _dispatcher.command(
        UpdatePostCommand(id: post.id, title: title, body: body),
      );
      final updated = await _dispatcher.query(
        GetPostQuery(post.id, cancellation: _cancellation.token),
      );
      // The list below is now wrong about this post.
      _revision.markStale();
      // The write landed either way, so this answers true; the signal is what
      // stays silent once the page is gone.
      if (_isDisposed) return true;
      _post.setValue(updated);
      _update.setValue(null);
      return true;
    } catch (error, stackTrace) {
      // The re-read can be dropped on the way out; the edit itself already
      // landed. See `PostsHomeViewModel.createPost` for why this answers false.
      if (_isDisposed) return false;
      _update.setError(error, stackTrace);
      return false;
    }
  }

  // Sends the delete. Answers whether it worked, so the page knows whether to
  // leave a screen that no longer has a post to show.
  Future<bool> deletePost() async {
    final post = _settledPost;
    if (post == null) return false;

    _delete.setLoading();

    try {
      await _dispatcher.command(DeletePostCommand(post.id));
      // The list below still has it.
      _revision.markStale();
      if (_isDisposed) return true;
      _delete.setValue(null);
      return true;
    } catch (error, stackTrace) {
      if (_isDisposed) return false;
      _delete.setError(error, stackTrace);
      return false;
    }
  }

  // Walking away: the provider above the page calls this when the route
  // unmounts.
  //
  // The flag comes first and the cancellation second, so a read the cancellation
  // drops finds the view model already closed and writes nothing back. A signal
  // that has been disposed *throws* on a write, which is why every write above
  // checks the flag first.
  void dispose() {
    _isDisposed = true;
    _cancellation.cancel();
    _post.dispose();
    _update.dispose();
    _delete.dispose();
  }

  // The post the read has settled on, or `null` while it is loading, after a
  // failure, and for an id that resolved to nothing. `hasValue` also covers the
  // reloading and refreshing states, where the post on screen is the old one.
  Post? get _settledPost {
    final state = _post.value;
    return state.hasValue ? state.value : null;
  }
}
