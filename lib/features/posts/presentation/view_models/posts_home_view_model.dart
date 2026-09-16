import 'package:cqrs/cqrs.dart';
import 'package:flutter/foundation.dart';
import 'package:injectify/injectify.dart';

import '../../../../core/async/cancellation.dart';
import '../../domain/entities/post.dart';
import '../../domain/usecases/create_post_command.dart';
import '../../domain/usecases/get_posts_query.dart';
import '../posts_watch.dart';

// State for the posts list. Factory-scoped: one per page, disposed by the
// `ChangeNotifierProvider` that created it.
@Injectable(scope: Scope.factory)
class PostsHomeViewModel extends ChangeNotifier {
  PostsHomeViewModel(this._dispatcher, this._watch) {
    _watch.addListener(_onStale);
  }

  // The demo has no signed-in user, and jsonplaceholder only echoes this back.
  static const _authorId = 1;

  final CqrsDispatcher _dispatcher;
  final PostsWatch _watch;

  // The page's way out of its own reads. Disposal *is* the page going away —
  // the provider disposes this view model when it unmounts — so a read still in
  // flight is dropped there instead of finishing into a screen nobody is
  // watching.
  final _cancellation = CancellationSource();

  List<Post>? _posts;
  Object? _error;
  bool _isLoading = false;
  bool _isDisposed = false;

  // `null` before the first load completes.
  List<Post>? get posts => _posts;

  Object? get error => _error;

  bool get isLoading => _isLoading;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    _notify();

    try {
      _posts = await _dispatcher.query(
        GetPostsQuery(cancellation: _cancellation.token),
      );
    } catch (error) {
      // A dropped read is not a failure: there is nobody left to report it to.
      // Everything else is.
      if (_cancellation.isCancelled) return;
      _error = error;
    } finally {
      _isLoading = false;
      _notify();
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
    _error = null;

    try {
      await _dispatcher.command(
        CreatePostCommand(userId: _authorId, title: title, body: body),
      );
      _posts = await _dispatcher.query(
        GetPostsQuery(cancellation: _cancellation.token),
      );
      return true;
    } catch (error) {
      // The re-read can be dropped on the way out. The write itself already
      // landed, and there is nobody left to be told either way — so this
      // answers the conservative thing rather than the true one.
      if (_cancellation.isCancelled) return false;
      _error = error;
      return false;
    } finally {
      _notify();
    }
  }

  @override
  void dispose() {
    // Stop taking new work before dropping what is in flight, so a notification
    // already in the queue cannot start a read on the way out.
    _watch.removeListener(_onStale);
    _cancellation.cancel();
    _isDisposed = true;
    super.dispose();
  }

  // A page above this one wrote, so what this page holds no longer matches.
  void _onStale() => load();

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }
}
