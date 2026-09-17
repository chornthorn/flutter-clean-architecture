import 'package:flutter/widgets.dart';

import '../action_result.dart';

/// State controller for managing both client-side and server-side form states.
///
/// Features:
/// - Provides [formKey] ([GlobalKey<FormState>]) to control the Flutter [Form].
/// - Provides [validate], [save], and [reset] convenience methods.
/// - Stores server-side error mapping bindable directly to [ActionResult].
/// - Works seamlessly with [AppFormScope] and [AppTextField].
class FormErrorController extends ChangeNotifier {
  FormErrorController([
    Map<String, String> initial = const {},
    GlobalKey<FormState>? formKey,
  ])  : _errors = Map<String, String>.from(initial),
        formKey = formKey ?? GlobalKey<FormState>();

  /// Named constructor to explicitly supply a custom [formKey].
  FormErrorController.withKey(
    this.formKey, [
    Map<String, String> initial = const {},
  ])  : _errors = Map<String, String>.from(initial);

  final Map<String, String> _errors;

  /// The [GlobalKey<FormState>] controlling the enclosing [Form].
  final GlobalKey<FormState> formKey;

  /// The current [FormState] from [formKey], or null if not currently mounted.
  FormState? get formState => formKey.currentState;

  /// Validates every descendant [FormField] in the form tree.
  ///
  /// Returns `true` if all fields pass client-side validation.
  bool validate() => formState?.validate() ?? true;

  /// Calls [FormFieldState.save] on every descendant field.
  void save() => formState?.save();

  /// Resets every descendant [FormField] back to initial values
  /// and clears all server-side field errors.
  void reset() {
    formState?.reset();
    clear();
  }

  /// Returns the current validation error for [fieldKey], or null if valid.
  String? operator [](String fieldKey) => _errors[fieldKey];

  /// Whether any field currently has an error.
  bool get hasErrors => _errors.isNotEmpty;

  /// Whether [fieldKey] currently has an error.
  bool hasField(String fieldKey) => _errors.containsKey(fieldKey);

  /// An unmodifiable view of all active field errors.
  Map<String, String> get errors => Map.unmodifiable(_errors);

  /// Overwrites all errors with [errors] and notifies listeners.
  void setErrors(Map<String, String> errors) {
    _errors
      ..clear()
      ..addAll(errors);
    notifyListeners();
  }

  /// Sets or updates the error message for [fieldKey].
  void setField(String fieldKey, String error) {
    _errors[fieldKey] = error;
    notifyListeners();
  }

  /// Removes the error for [fieldKey] if present and notifies listeners.
  void clearField(String fieldKey) {
    if (_errors.containsKey(fieldKey)) {
      _errors.remove(fieldKey);
      notifyListeners();
    }
  }

  /// Clears all field errors and notifies listeners if any were present.
  void clear() {
    if (_errors.isNotEmpty) {
      _errors.clear();
      notifyListeners();
    }
  }

  /// Binds an [ActionResult]:
  /// - [ActionFailure]: loads [ActionFailure.fieldErrors]
  /// - [ActionSuccess]: clears all errors
  void bind(ActionResult result) {
    if (result is ActionFailure) {
      setErrors(result.fieldErrors);
    } else {
      clear();
    }
  }
}
