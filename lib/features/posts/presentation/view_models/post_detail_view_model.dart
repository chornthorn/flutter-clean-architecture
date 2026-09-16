import 'package:cqrs/cqrs.dart';
import 'package:flutter/foundation.dart';
import 'package:injectify/injectify.dart';

import '../../domain/entities/post.dart';
import '../../domain/usecases/get_post_query.dart';

// State for one post. Same scope and lifecycle rules as the other view models.
//
// The id is a `load` argument rather than a field: it comes from the route, and
// the page that owns it passes it in.
@Injectable(scope: Scope.factory)
class PostDetailViewModel extends ChangeNotifier {
  PostDetailViewModel(this._dispatcher);

  final CqrsDispatcher _dispatcher;

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
      _post = await _dispatcher.query(GetPostQuery(id));
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
