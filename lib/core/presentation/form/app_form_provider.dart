import 'package:flutter/widgets.dart';

import 'app_form_controller.dart';

export 'form_field_key.dart';

/// Scopes an [AppFormController] to a subtree, enabling forms on the same
/// screen to manage validation errors independently without collision.
class AppFormProvider extends InheritedNotifier<AppFormController> {
  const AppFormProvider({
    super.key,
    required AppFormController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Resolves the nearest [AppFormController] in the widget tree, or null if none.
  static AppFormController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppFormProvider>()
        ?.notifier;
  }

  /// Resolves the nearest [AppFormController] in the widget tree.
  /// Throws an [AssertionError] in debug mode if not found.
  static AppFormController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(
      controller != null,
      'No AppFormProvider found in the current BuildContext.',
    );
    return controller!;
  }

  /// Looks up the server error for [fieldKey] from the enclosing [AppFormProvider].
  static String? errorOf(BuildContext context, FormFieldKey fieldKey) {
    return maybeOf(context)?[fieldKey];
  }

  /// Clears the server error for [fieldKey] in the enclosing [AppFormProvider].
  static void clearErrorOf(BuildContext context, FormFieldKey fieldKey) {
    maybeOf(context)?.clearField(fieldKey);
  }
}
