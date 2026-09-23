import 'package:flutter/foundation.dart';

import '../async/cancellation.dart';

/// The lifecycle a page's state holder owes the route that owns it.
///
/// A view model takes the use cases it needs through its constructor, and the
/// container builds it:
///
/// ```dart
/// class PostsHomeViewModel extends ViewModel {
///   PostsHomeViewModel(this._getPosts);
///
///   final GetPostsUseCase _getPosts;
/// }
/// ```
///
/// The base owns the one thing every view model owes the route: a scope that
/// ends when the page does. [dispose] cancels that scope before the subclass
/// releases anything, so a response that lands after the page is gone finds
/// [isAlive] false and has nowhere to write. A subclass cannot forget the
/// cancel, because a subclass never writes it.
abstract class ViewModel {
  final _scope = CancellationSource();

  /// The token every call this view model starts carries.
  ///
  /// Hand it to every use case, so the request is dropped at the transport when
  /// the route goes away instead of running on for nobody.
  @protected
  Cancellation get cancellation => _scope.token;

  /// Whether the route still owns this view model.
  ///
  /// Read it after every `await`, before touching a signal or a form controller:
  /// writing to a disposed signal throws `SignalsWriteAfterDisposeError`, in
  /// release as well as debug.
  @protected
  bool get isAlive => !_scope.isCancelled;

  /// Ends this view model's scope and releases what it holds.
  ///
  /// The route's provider calls this when the page unmounts. The scope is
  /// cancelled first, so nothing this view model started can land afterwards.
  /// Idempotent, and not overridable — a subclass implements [onDispose].
  @nonVirtual
  void dispose() {
    if (!isAlive) return;
    _scope.cancel();
    onDispose();
  }

  /// Releases the signals, controllers and subscriptions this view model holds.
  ///
  /// Runs once, after the scope is cancelled, so the work this view model
  /// started is already dropped by the time its state goes away.
  @protected
  void onDispose() {}
}
