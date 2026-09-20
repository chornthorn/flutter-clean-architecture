import 'package:cqrs/cqrs.dart';

/// The lifecycle a page's state holder owes the route that owns it.
///
/// Every view model receives the app's dispatcher through the constructor and
/// forwards it with `super`, so a subclass uses `dispatcher` directly instead of
/// holding a field of its own:
///
/// ```dart
/// class PostsHomeViewModel extends ViewModel {
///   PostsHomeViewModel({required super.dispatcher});
/// }
/// ```
abstract class ViewModel {
  ViewModel({required this.dispatcher});

  /// The app's CQRS entry point: every read and every write a screen makes goes
  /// through here, and nothing else in the app dispatches.
  final CqrsDispatcher dispatcher;

  /// Stops the work this view model started and releases what it holds.
  ///
  /// The route's provider calls this when the page unmounts. Idempotent.
  void dispose();
}
