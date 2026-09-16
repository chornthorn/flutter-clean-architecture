import 'package:cqrs/cqrs.dart';
import 'package:flutter/foundation.dart';
import 'package:injectify/injectify.dart';

import '../../../../core/async/cancellation.dart';
import '../../domain/entities/post.dart';
import '../../domain/usecases/delete_post_command.dart';
import '../../domain/usecases/get_post_query.dart';
import '../../domain/usecases/update_post_command.dart';
import '../posts_watch.dart';

// State for one post. Same scope and lifecycle rules as the other view models.
//
// The id is a `load` argument rather than a field: it comes from the route, and
// the page that owns it passes it in.
@Injectable(scope: Scope.factory)
class PostDetailViewModel extends ChangeNotifier {
  PostDetailViewModel(this._dispatcher, this._watch);

  final CqrsDispatcher _dispatcher;
  final PostsWatch _watch;

  // See `PostsHomeViewModel`: cancelling in `dispose` is the page walking away
  // from whatever read is still in flight.
  final _cancellation = CancellationSource();

  Post? _post;
  Object? _error;
  bool _isLoading = false;
  bool _isDisposed = false;

  // `null` while loading, and `null` once a missing id has resolved —
  // [isLoading] tells the two apart.
  Post? get post => _post;

  Object? get error => _error;

  bool get isLoading => _isLoading;

  Future<void> load(int id) async {
    _isLoading = true;
    _error = null;
    _notify();

    try {
      _post = await _dispatcher.query(
        GetPostQuery(id, cancellation: _cancellation.token),
      );
    } catch (error) {
      // A dropped read is not a failure: there is nobody left to report it to.
      if (_cancellation.isCancelled) return;
      _error = error;
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  // Sends the edit, then re-reads the post rather than patching a local copy.
  // Answers whether it worked, so the form knows whether to close.
  Future<bool> updatePost({required String title, required String body}) async {
    final post = _post;
    if (post == null) return false;

    _error = null;

    try {
      await _dispatcher.command(
        UpdatePostCommand(id: post.id, title: title, body: body),
      );
      _post = await _dispatcher.query(
        GetPostQuery(post.id, cancellation: _cancellation.token),
      );
      // The list below is now wrong about this post.
      _watch.markStale();
      return true;
    } catch (error) {
      // The re-read can be dropped on the way out; the edit itself already
      // landed. See `PostsHomeViewModel.createPost` for why this answers false.
      if (_cancellation.isCancelled) return false;
      _error = error;
      return false;
    } finally {
      _notify();
    }
  }

  // Sends the delete. Answers whether it worked, so the page knows whether to
  // leave a screen that no longer has a post to show.
  Future<bool> deletePost() async {
    final post = _post;
    if (post == null) return false;

    _error = null;

    try {
      await _dispatcher.command(DeletePostCommand(post.id));
      // The list below still has it.
      _watch.markStale();
      return true;
    } catch (error) {
      _error = error;
      return false;
    } finally {
      _notify();
    }
  }

  @override
  void dispose() {
    _cancellation.cancel();
    _isDisposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }
}
