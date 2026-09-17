import 'package:cqrs/cqrs.dart';
import 'package:injectify/injectify.dart';
import 'package:signals/signals_flutter.dart';

import '../../../../core/async/cancellation.dart';
import '../../../../core/presentation/view_model.dart';
import '../../domain/entities/post.dart';
import '../../domain/usecases/delete_post_command.dart';
import '../../domain/usecases/get_post_query.dart';
import '../../domain/usecases/update_post_command.dart';

// State for one post: one signal per use case, per `docs/architecture.md`.
@Injectable(scope: Scope.factory)
class PostDetailViewModel implements ViewModel {
  PostDetailViewModel(this._dispatcher);

  final CqrsDispatcher _dispatcher;
  final _cancellation = CancellationSource();

  bool _isDisposed = false;

  final _post = asyncSignal<Post?>(AsyncState.loading());

  // Settled, not loading: no write has run yet.
  final _update = asyncSignal<void>(AsyncState.data(null));
  final _delete = asyncSignal<void>(AsyncState.data(null));

  ReadonlySignal<AsyncState<Post?>> get post => _post;
  ReadonlySignal<AsyncState<void>> get update => _update;
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
      if (_isDisposed) return;
      _post.setError(error, stackTrace);
    }
  }

  // Answers whether it worked, so the form knows whether to close.
  Future<bool> updatePost(
    int id, {
    required String title,
    required String body,
  }) async {
    _update.setLoading();

    try {
      await _dispatcher.command(
        UpdatePostCommand(id: id, title: title, body: body),
      );
      final updated = await _dispatcher.query(
        GetPostQuery(id, cancellation: _cancellation.token),
      );
      if (_isDisposed) return true;
      _post.setValue(updated);
      _update.setValue(null);
      return true;
    } catch (error, stackTrace) {
      if (_isDisposed) return false;
      _update.setError(error, stackTrace);
      return false;
    }
  }

  // Answers whether it worked, so the page knows whether to leave.
  Future<bool> deletePost(int id) async {
    _delete.setLoading();

    try {
      await _dispatcher.command(DeletePostCommand(id));
      if (_isDisposed) return true;
      _delete.setValue(null);
      return true;
    } catch (error, stackTrace) {
      if (_isDisposed) return false;
      _delete.setError(error, stackTrace);
      return false;
    }
  }

  // The provider calls this when the page unmounts. A disposed signal throws on a
  // write, which is what the guards above are for.
  @override
  void dispose() {
    _isDisposed = true;
    _cancellation.cancel();
    _post.dispose();
    _update.dispose();
    _delete.dispose();
  }
}
