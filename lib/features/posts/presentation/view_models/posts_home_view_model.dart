import 'package:cqrs/cqrs.dart';
import 'package:flutter/foundation.dart';
import 'package:injectify/injectify.dart';

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
      _posts = await _dispatcher.query(const GetPostsQuery());
    } catch (error) {
      _error = error;
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  // Sends the command, then re-reads the list rather than inserting locally.
  // Answers whether it worked, so the form knows whether to close.
  Future<bool> createPost({required String title, required String body}) async {
    _error = null;

    try {
      await _dispatcher.command(
        CreatePostCommand(userId: _authorId, title: title, body: body),
      );
      _posts = await _dispatcher.query(const GetPostsQuery());
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
    _watch.removeListener(_onStale);
    _isDisposed = true;
    super.dispose();
  }

  // A page above this one wrote, so what this page holds no longer matches.
  void _onStale() => load();

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }
}
