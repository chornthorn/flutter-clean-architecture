import 'package:flutter/material.dart';

import '../../presentation/form/form_error_scope.dart';
import '../app_theme.g.dart';

/// Design-system compliant text input built on Flutter's [TextFormField].
///
/// Features:
/// - Built directly on top of [TextFormField], integrating natively with Flutter's
///   [Form] and [AppFormScope] (`validator`, `autovalidateMode`, `onSaved`,
///   `formKey.currentState!.validate()`).
/// - Inherits [AutovalidateMode] from [AppFormScope] options if not specified on the field.
/// - When [fieldKey] is provided:
///   - Automatically displays server-side errors from the enclosing [FormErrorScope].
///   - Automatically clears server errors as soon as the user starts editing.
/// - Error precedence: explicit [errorText] -> client [validator] -> server [fieldKey] error.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.fieldKey,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.label,
    this.hint,
    this.errorText,
    this.validator,
    this.onChanged,
    this.onSaved,
    this.onSubmitted,
    this.onFieldSubmitted,
    this.autovalidateMode,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.minLines,
    this.isEnabled = true,
  });

  /// The form field identifier used to look up server errors from [FormErrorScope].
  final String? fieldKey;

  final TextEditingController? controller;
  final String? initialValue;
  final FocusNode? focusNode;
  final String? label;
  final String? hint;

  /// Explicit error text. If provided, overrides any client or server error.
  final String? errorText;

  /// Client-side validation function.
  final FormFieldValidator<String>? validator;

  final ValueChanged<String>? onChanged;
  final FormFieldSetter<String>? onSaved;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onFieldSubmitted;

  /// Field-level override for [AutovalidateMode]. If null, inherits from [AppFormScope].
  final AutovalidateMode? autovalidateMode;

  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int? maxLines;
  final int? minLines;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final errorScope = FormErrorScope.maybeOf(context);

    // Look up server-side error for this field
    final serverError = (fieldKey != null && errorScope != null)
        ? errorScope[fieldKey!]
        : null;

    // Error precedence: explicit widget override -> server-side error (client validator overrides via TextFormField)
    final effectiveErrorText = errorText ?? serverError;

    // Inherit autovalidateMode from enclosing Form/AppFormScope if not set on the field
    final effectiveAutovalidateMode = autovalidateMode ??
        Form.maybeOf(context)?.widget.autovalidateMode ??
        AutovalidateMode.disabled;

    final borderRadius = BorderRadius.circular(theme.sizes.radius.md);
    final border = OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: theme.colors.surface.border),
    );
    final errorBorder = OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: theme.colors.feedback.danger),
    );

    return TextFormField(
      controller: controller,
      initialValue: initialValue,
      focusNode: focusNode,
      enabled: isEnabled,
      autovalidateMode: effectiveAutovalidateMode,
      validator: validator,
      onSaved: onSaved,
      onChanged: (value) {
        if (fieldKey != null) {
          errorScope?.clearField(fieldKey!);
        }
        onChanged?.call(value);
      },
      onFieldSubmitted: onFieldSubmitted ?? onSubmitted,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLines: maxLines,
      minLines: minLines,
      style: theme.typography.body.regular,
      cursorColor: theme.colors.brand.primary,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: effectiveErrorText,
        labelStyle: theme.typography.label.regular,
        floatingLabelStyle: theme.typography.label.regular.copyWith(
          color: theme.colors.brand.primary,
        ),
        errorStyle: theme.typography.label.regular.copyWith(
          color: theme.colors.feedback.danger,
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
