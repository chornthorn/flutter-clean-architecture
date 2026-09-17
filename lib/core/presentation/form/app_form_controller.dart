import 'package:flutter/widgets.dart';
import 'package:signals/signals_flutter.dart' as sig;
import 'package:signals/signals_flutter.dart';

import '../action_result.dart';
import 'form_field_key.dart';

export 'form_field_key.dart';

/// State controller for managing client-side form values, text editing controllers,
/// signals, and server-side validation error states.
///
/// Features:
/// - Provides [formKey] ([GlobalKey<FormState>]) to control the Flutter [Form].
/// - Provides [validate], [save], and [reset] convenience methods.
/// - Manages lifecycle of [TextEditingController]s and reactive [Signal]s per [FormFieldKey].
/// - Automatic bidirectional synchronization between text editing controllers and signals.
/// - Automatic server-side error clearing when a user modifies text.
/// - Stores server-side error mapping bindable directly to [ActionResult].
/// - Works seamlessly with [AppFormScope] and [AppTextField].
/// - Uses [FormFieldKey] extension type for zero-cost type-safe field lookups.
class AppFormController extends ChangeNotifier {
  AppFormController([
    Map<String, String> initialErrors = const {},
    GlobalKey<FormState>? formKey,
    Map<dynamic, String> initialValues = const {},
  ]) : _errors = Map<String, String>.from(initialErrors),
       _initialValues = {},
       formKey = formKey ?? GlobalKey<FormState>() {
    if (initialValues.isNotEmpty) {
      setValues(initialValues);
    }
  }

  /// Named constructor to explicitly supply a custom [formKey].
  AppFormController.withKey(
    this.formKey, [
    Map<String, String> initialErrors = const {},
    Map<dynamic, String> initialValues = const {},
  ]) : _errors = Map<String, String>.from(initialErrors),
       _initialValues = {} {
    if (initialValues.isNotEmpty) {
      setValues(initialValues);
    }
  }

  /// Named factory constructor to initialize with field values.
  factory AppFormController.fromValues(
    Map<dynamic, String> initialValues, {
    Map<String, String> initialErrors = const {},
    GlobalKey<FormState>? formKey,
  }) {
    return AppFormController(initialErrors, formKey, initialValues);
  }

  /// Key to attach to the Flutter [Form].
  final GlobalKey<FormState> formKey;

  final Map<String, String> _errors;
  final Map<String, String> _initialValues;
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, Signal<String>> _signals = {};
  final Map<String, VoidCallback> _signalEffects = {};

  /// Direct access to the underlying [FormState], or null if not yet mounted.
  FormState? get formState => formKey.currentState;

  /// Validates every descendant [FormField] in the form tree.
  ///
  /// Returns true if all fields are valid, false otherwise.
  bool validate() => formState?.validate() ?? false;

  /// Calls [FormFieldState.save] on every descendant field.
  void save() => formState?.save();

  /// Resets every descendant [FormField] back to initial values,
  /// restores managed controllers to their initial values,
  /// and clears all server-side errors.
  void reset() {
    formState?.reset();
    for (final entry in _controllers.entries) {
      final initial = _initialValues[entry.key] ?? '';
      if (entry.value.text != initial) {
        entry.value.value = entry.value.value.copyWith(
          text: initial,
          selection: TextSelection.collapsed(offset: initial.length),
          composing: TextRange.empty,
        );
      }
    }
    clear();
  }

  /// Obtains or creates a managed [TextEditingController] for [fieldKey].
  ///
  /// The controller is automatically synced with [signal] and auto-clears
  /// server-side errors on typing. When this [AppFormController] is disposed,
  /// all created controllers are disposed automatically.
  TextEditingController controller(
    FormFieldKey fieldKey, [
    String? defaultInitialValue,
  ]) {
    return _controllers.putIfAbsent(fieldKey.key, () {
      final initial = _findInitialValue(fieldKey) ?? defaultInitialValue ?? '';
      _initialValues[fieldKey.key] = initial;
      final c = TextEditingController(text: initial);
      c.addListener(() {
        final sig = _signals[fieldKey.key];
        if (sig != null && sig.value != c.text) {
          sig.value = c.text;
        }
        clearField(fieldKey);
      });
      return c;
    });
  }

  /// Returns a reactive [Signal<String>] tracking the value of [fieldKey].
  ///
  /// Updates bidirectionally with the underlying [TextEditingController]:
  /// modifying [signal.value] updates the text field, and user input updates
  /// [signal.value].
  Signal<String> signal(FormFieldKey fieldKey) {
    return _signals.putIfAbsent(fieldKey.key, () {
      final ctrl = controller(fieldKey);
      final s = sig.signal<String>(ctrl.text);
      final disposeEffect = sig.effect(() {
        final val = s.value;
        if (ctrl.text != val) {
          ctrl.value = ctrl.value.copyWith(
            text: val,
            selection: TextSelection.collapsed(offset: val.length),
            composing: TextRange.empty,
          );
        }
      });
      _signalEffects[fieldKey.key] = disposeEffect;
      return s;
    });
  }

  /// Returns the current text string for [fieldKey].
  String text(FormFieldKey fieldKey) {
    final ctrl = _controllers[fieldKey.key];
    if (ctrl != null) return ctrl.text;
    return _findInitialValue(fieldKey) ?? '';
  }

  /// Alias for [text].
  String getValue(FormFieldKey fieldKey) => text(fieldKey);

  /// Sets or updates the text value for [fieldKey].
  ///
  /// Updates any existing [TextEditingController] and [Signal] for this field.
  void setValue(FormFieldKey fieldKey, String value) {
    _initialValues[fieldKey.key] = value;
    final ctrl = _controllers[fieldKey.key];
    if (ctrl != null && ctrl.text != value) {
      ctrl.value = ctrl.value.copyWith(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
        composing: TextRange.empty,
      );
    }
    final s = _signals[fieldKey.key];
    if (s != null && s.value != value) {
      s.value = value;
    }
  }

  /// Updates multiple field values at once.
  ///
  /// Supports keys that are [FormFieldKey], [FormFieldKeyBase] (such as enums),
  /// or [String].
  void setValues(Map<dynamic, String> values) {
    for (final entry in values.entries) {
      final k = entry.key;
      if (k is FormFieldKey) {
        setValue(k, entry.value);
      } else if (k is FormFieldKeyBase) {
        setValue(FormFieldKey(k), entry.value);
      } else if (k is String) {
        _setRawValue(k, entry.value);
      }
    }
  }

  void _setRawValue(String rawKey, String value) {
    _initialValues[rawKey] = value;
    final ctrl = _controllers[rawKey];
    if (ctrl != null && ctrl.text != value) {
      ctrl.value = ctrl.value.copyWith(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
        composing: TextRange.empty,
      );
    }
    final s = _signals[rawKey];
    if (s != null && s.value != value) {
      s.value = value;
    }
  }

  /// Resets all field text values to empty strings.
  void clearValues() {
    for (final key in _controllers.keys.toList()) {
      _setRawValue(key, '');
    }
    _initialValues.clear();
  }

  String? _findInitialValue(FormFieldKey fieldKey) {
    return _initialValues[fieldKey.key] ??
        _initialValues[fieldKey.snakeCase] ??
        _initialValues[fieldKey.camelCase];
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

  @override
  void dispose() {
    for (final disposeEffect in _signalEffects.values) {
      disposeEffect();
    }
    _signalEffects.clear();
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    _controllers.clear();
    _signals.clear();
    super.dispose();
  }
}
