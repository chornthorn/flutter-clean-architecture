import 'dart:async';

// The app's "stop working on this" signal.
//
// A `Future` cannot be cancelled — awaiting one only waits. So a page that is
// popped, or a dialog that is closed, leaves the read it started running to
// completion: the socket is read, the payload decoded, the result assigned to a
// view model nobody is watching. Marking the view model disposed stops the
// *notification*; it does not stop the work.
//
// This is what stops the work. The screen that owns the request holds the source
// and hands its token down with every read it starts:
//
// ```dart
// final cancellation = CancellationSource();
// try {
//   posts = await _dispatcher.query(GetPostsQuery(cancellation: cancellation.token));
// } catch (error) {
//   if (cancellation.isCancelled) return; // nobody left to tell
//   _error = error;
// } finally { ... }
// ```
//
// The token travels as a bare `Future` — [Cancellation] below — rather than as
// this class, so a feature's `domain/` contract can carry it without depending on
// anything that does IO. A use case that has to import an HTTP client to say
// "cancel" has stopped being plain Dart; one that takes a `Cancellation` has not.

/// The signal a caller hands down with a read it may walk away from: completes
/// when it has.
///
/// [CancellationSource] is the end that cancels; this is the end that travels.
/// Domain may import this file — and only this one — because it is plain Dart
/// over `dart:async` with no IO in it, which is all the "domain stays plain
/// Dart" rule protects.
typedef Cancellation = Future<void>;

/// Owns the cancelling end of the work one screen started.
///
/// One per scope: a view model holds one for its lifetime and cancels it in
/// `dispose`, which is exactly when the provider that created it unmounts.
class CancellationSource {
  final _token = Completer<void>();
  bool _isCancelled = false;

  /// Completes when the owner walks away. Hand this down with every request the
  /// scope starts.
  Cancellation get token => _token.future;

  /// True once [cancel] has run.
  ///
  /// This is what tells a dropped request apart from one that failed. They
  /// arrive the same way — as a thrown error — and only one of them is worth
  /// reporting to a screen.
  bool get isCancelled => _isCancelled;

  /// Drops the work: everything holding [token] stops what it is doing.
  ///
  /// Idempotent, and safe to call when nothing is in flight.
  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    _token.complete();
  }
}
