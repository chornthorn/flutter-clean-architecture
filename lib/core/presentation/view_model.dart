/// The lifecycle a page's state holder owes the route that owns it.
///
/// `interface class` is the whole design: nothing outside this file can `extend`
/// it, so it can never grow behavior a view model inherits without asking for it.
abstract interface class ViewModel {
  /// Stops the work this view model started and releases what it holds.
  ///
  /// The route's provider calls this when the page unmounts. Idempotent.
  void dispose();
}
