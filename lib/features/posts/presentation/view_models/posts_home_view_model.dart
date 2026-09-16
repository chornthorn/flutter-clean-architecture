import 'package:cqrs/cqrs.dart';
import 'package:flutter/foundation.dart';
import 'package:injectify/injectify.dart';

import '../../domain/entities/post.dart';
import '../../domain/usecases/get_posts_query.dart';

// State for the posts list. Factory-scoped: one per page, disposed by the
// `ChangeNotifierProvider` that created it.
@Injectable(scope: Scope.factory)
class PostsHomeViewModel extends ChangeNotifier {
  PostsHomeViewModel(this._dispatcher);

  final CqrsDispatcher _dispatcher;

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

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }
}
