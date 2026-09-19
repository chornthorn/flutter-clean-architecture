import 'package:cqrs/cqrs.dart';

import '../execution/execution_context.dart';

/// The lifecycle a page's state holder owes the route that owns it.
///
/// Every view model receives the two things every screen needs — the app's
/// dispatcher, and the scope its screen runs in — through the constructor, the
/// way a widget takes its arguments and its `key`:
///
/// ```dart
/// class PostsHomeViewModel extends ViewModel {
///   PostsHomeViewModel({required super.dispatcher, required super.context});
/// }
/// ```
///
/// Both are forwarded with `super`, so a subclass uses them directly and never
/// reaches for a container: `dispatcher` for every read and write, `context` to
/// capture the action, carry the cancellation and reach the screen's providers.
///
/// This file used to hold an `interface class` with `dispose()` as its only
/// member, on the grounds that a view model should inherit nothing it did not ask
/// for. These two are what every view model does ask for.
abstract class ViewModel {
  ViewModel({required this.dispatcher, required this.context}) {
    context.host = runtimeType;
  }

  /// The app's CQRS entry point: every read and every write a screen makes goes
  /// through here, and nothing else in the app dispatches.
  final CqrsDispatcher dispatcher;

  /// This screen's scope: its providers, its cancellation, its capture.
  final ExecutionContext context;

  /// Whether the route is gone — the replacement for a `_isDisposed` flag.
  bool get isDisposed => context.isClosed;

  /// The route unmounted: stop the work in flight and release what the screen
  /// created. An override must call `super.dispose()`.
  void dispose() => context.close();
}
