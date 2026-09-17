import 'package:flutter/widgets.dart';

import '../action_result.dart';
import 'form_field_key.dart';

export 'form_field_key.dart';

/// State controller for managing both client-side and server-side form states.
///
/// Features:
/// - Provides [formKey] ([GlobalKey<FormState>]) to control the Flutter [Form].
/// - Provides [validate], [save], and [reset] convenience methods.
/// - Stores server-side error mapping bindable directly to [ActionResult].
/// - Works seamlessly with [AppFormScope] and [AppTextField].
/// - Uses [FormFieldKey] extension type for zero-cost type-safe field lookups.
class AppFormController extends ChangeNotifier {
  AppFormController([
    Map<String, String> initial = const {},
    GlobalKey<FormState>? formKey,
  ])  : _errors = Map<String, String>.from(initial),
        formKey = formKey ?? GlobalKey<FormState>();

  /// Named constructor to explicitly supply a custom [formKey].
  AppFormController.withKey(
    this.formKey, [
    Map<String, String> initial = const {},
  ]) : _errors = Map<String, String>.from(initial);

  /// Key to attach to the Flutter [Form].
  final GlobalKey<FormState> formKey;

  final Map<String, String> _errors;

  /// Direct access to the underlying [FormState], or null if not yet mounted.
  FormState? get formState => formKey.currentState;

  /// Validates every descendant [FormField] in the form tree.
  ///
  /// Returns true if all fields are valid, false otherwise.
  bool validate() => formState?.validate() ?? false;

  /// Calls [FormFieldState.save] on every descendant field.
  void save() => formState?.save();

  /// Resets every descendant [FormField] back to initial values
  /// and clears all server-side errors.
  void reset() {
    formState?.reset();
    clear();
  }

  /// Returns the current validation error for [fieldKey], or null if valid.
  ///
  /// Matches exact [fieldKey.key], and falls back to [fieldKey.snakeCase]
  /// or [fieldKey.camelCase] to seamlessly bridge backend naming conventions
  /// (e.g. `isAvailable` vs `is_available`).
  String? operator [](FormFieldKey fieldKey) =>
      _errors[fieldKey.key] ??
      _errors[fieldKey.snakeCase] ??
      _errors[fieldKey.camelCase];

  /// Whether any field currently has an error.
  bool get hasErrors => _errors.isNotEmpty;

  /// Whether [fieldKey] currently has an error.
  bool hasField(FormFieldKey fieldKey) =>
      _errors.containsKey(fieldKey.key) ||
      _errors.containsKey(fieldKey.snakeCase) ||
      _errors.containsKey(fieldKey.camelCase);

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
  void setField(FormFieldKey fieldKey, String error) {
    _errors[fieldKey.key] = error;
    notifyListeners();
  }

  /// Removes the error for [fieldKey] if present and notifies listeners.
  void clearField(FormFieldKey fieldKey) {
    final keysToRemove = {fieldKey.key, fieldKey.snakeCase, fieldKey.camelCase};
    var removed = false;
    for (final k in keysToRemove) {
      if (_errors.remove(k) != null) {
        removed = true;
      }
    }
    if (removed) {
      notifyListeners();
    }
  }

  /// Clears all field errors and notifies listeners.
  void clear() {
    if (_errors.isNotEmpty) {
      _errors.clear();
      notifyListeners();
    }
  }

  /// Convenience method to bind field errors from an [ActionResult].
  ///
  /// If [result] is an [ActionFailure] with [ActionFailure.fieldErrors],
  /// replaces the current errors and notifies. If [result] is [ActionSuccess],
  /// clears all errors.
  void bind(ActionResult result) {
    if (result is ActionFailure) {
      setErrors(result.fieldErrors);
    } else if (result is ActionSuccess) {
      clear();
    }
  }
}
