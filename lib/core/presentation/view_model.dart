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
/// The base carries the lifecycle and nothing else. What a view model holds and
/// how it reaches the domain is the view model's own business; the route only
/// needs to know how to end it.
abstract class ViewModel {
  /// Stops the work this view model started and releases what it holds.
  ///
  /// The route's provider calls this when the page unmounts. Idempotent.
  void dispose();
}
