/// The result of an action or mutation dispatched from a ViewModel.
///
/// Gives views a clean, typed status to decide navigation or toast alerts
/// without inspecting raw exceptions.
sealed class ActionResult {
  const ActionResult();

  const factory ActionResult.success([String? message]) = ActionSuccess;
  const factory ActionResult.failure(
    String message, {
    Map<String, String> fieldErrors,
  }) = ActionFailure;

  bool get isSuccess => this is ActionSuccess;
  bool get isFailure => this is ActionFailure;
}

final class ActionSuccess extends ActionResult {
  const ActionSuccess([this.message]);

  /// Optional feedback message to display in a toast or snackbar.
  final String? message;
}

final class ActionFailure extends ActionResult {
  const ActionFailure(this.message, {this.fieldErrors = const {}});

  /// User-visible error message.
  final String message;

  /// Optional field-specific errors for forms.
  final Map<String, String> fieldErrors;
}
