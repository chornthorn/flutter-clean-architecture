import 'dart:async';

// The app's "stop working on this" signal. A `Future` cannot be cancelled, so a
// read started by a page that is then popped keeps running — this is what drops
// it. See `core/README.md`.
//
// The token travels as a bare `Future` rather than as [CancellationSource], so a
// feature's `domain/` contract can carry it without depending on anything that
// does IO. Domain may import this file and no other `core/` file.

/// The signal a caller hands down with a read it may walk away from: completes
/// when it has.
typedef Cancellation = Future<void>;

/// Owns the cancelling end of the work one screen started.
///
/// One per scope: a view model holds one for its lifetime and cancels it in
/// `dispose`.
class CancellationSource {
  final _token = Completer<void>();
  bool _isCancelled = false;

  /// Completes when the owner walks away. Hand this down with every request.
  Cancellation get token => _token.future;

  /// True once [cancel] has run: what tells a dropped request from a failed one,
  /// which arrive the same way and only one of which is worth reporting.
  bool get isCancelled => _isCancelled;

  /// Drops the work. Idempotent, and safe when nothing is in flight.
  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    _token.complete();
  }
}
