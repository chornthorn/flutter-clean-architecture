import 'package:flutter/material.dart';

import '../../presentation/form/app_form_provider.dart';
import '../app_theme.g.dart';

export '../../presentation/form/form_field_key.dart';

/// Design-system compliant text input built directly on Flutter's [TextFormField].
///
/// Features:
/// - Full integration with Flutter's [Form] and [AppFormScope] (`validator`,
///   `autovalidateMode`, `onSaved`, `formKey.currentState!.validate()`).
/// - Inherits [AutovalidateMode] from [AppFormScope] options if not specified on the field.
/// - When [fieldKey] is provided:
///   - Automatically displays server-side errors from the enclosing [AppFormProvider].
///   - Automatically clears server errors as soon as the user starts editing.
/// - Error precedence: explicit [errorText] -> client [validator] -> server [fieldKey] error.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.fieldKey,
    this.controller,
    this.initialValue,
    this.label,
    this.hintText,
    this.helperText,
    this.errorText,
    this.validator,
    this.onSaved,
    this.onChanged,
    this.autovalidateMode,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.enabled,
    this.maxLines = 1,
    this.prefixIcon,
    this.suffixIcon,
    this.focusNode,
  });

  /// The form field identifier used to look up server errors from [AppFormProvider].
  final FormFieldKey? fieldKey;

  /// Controls the text being edited.
  final TextEditingController? controller;

  /// An optional initial value. Should only be set if [controller] is null.
  final String? initialValue;

  /// Optional label displayed inside or floating above the field.
  final String? label;

  /// Text that suggests what sort of input the field accepts.
  final String? hintText;

  /// Text that provides context about the field's input.
  final String? helperText;

  /// Explicit error text override. If provided, overrides validator & server errors.
  final String? errorText;

  /// Optional client-side validator callback.
  final FormFieldValidator<String>? validator;

  /// An optional method to call with the final value when the form is saved.
  final FormFieldSetter<String>? onSaved;

  /// Called when the user changes the text.
  final ValueChanged<String>? onChanged;

  /// Used to enable/disable auto validation and specify its mode.
  /// If null, inherits from enclosing [AppFormScope] (or [Form]).
  final AutovalidateMode? autovalidateMode;

  /// Whether to hide the text being edited (e.g. for passwords).
  final bool obscureText;

  /// The type of keyboard to use for editing the text.
  final TextInputType? keyboardType;

  /// The action button to use for the keyboard.
  final TextInputAction? textInputAction;

  /// If false, the text field is disabled.
  final bool? enabled;

  /// The maximum number of lines for multiline text.
  final int? maxLines;

  /// An optional leading widget.
  final Widget? prefixIcon;

  /// An optional trailing widget.
  final Widget? suffixIcon;

  /// Defines the keyboard focus for this widget.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final formProvider = AppFormProvider.maybeOf(context);

    // Look up any active server error for this field
    final serverError = (fieldKey != null && formProvider != null)
        ? formProvider[fieldKey!]
        : null;

    // Precedence: explicit errorText -> server error (validator handled by TextFormField)
    final effectiveErrorText = errorText ?? serverError;

    // Flutter's TextFormField defaults autovalidateMode to disabled if null.
    // Explicitly inherit from parent Form / AppFormScope if not specified locally.
    final effectiveAutovalidateMode =
        autovalidateMode ??
        Form.maybeOf(context)?.widget.autovalidateMode ??
        AutovalidateMode.disabled;

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(theme.sizes.radius.md),
      borderSide: BorderSide(color: theme.colors.surface.border),
    );

    final errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(theme.sizes.radius.md),
      borderSide: BorderSide(color: theme.colors.feedback.danger),
    );

    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      focusNode: focusNode,
      autovalidateMode: effectiveAutovalidateMode,
      validator: validator,
      onSaved: onSaved,
      onChanged: (value) {
        // Auto-clear server error when the user modifies text
        if (fieldKey != null &&
            formProvider != null &&
            formProvider.hasField(fieldKey!)) {
          formProvider.clearField(fieldKey!);
        }
        onChanged?.call(value);
      },
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      enabled: enabled,
      maxLines: maxLines,
      style: theme.typography.body.regular,
      cursorColor: theme.colors.brand.primary,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        helperText: helperText,
        errorText: effectiveErrorText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        labelStyle: theme.typography.label.regular,
        floatingLabelStyle: theme.typography.label.regular.copyWith(
          color: theme.colors.brand.primary,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: theme.colors.brand.primary, width: 2),
        ),
        errorBorder: errorBorder,
        focusedErrorBorder: errorBorder.copyWith(
          borderSide: BorderSide(color: theme.colors.feedback.danger, width: 2),
        ),
      ),
    );
  }
}
