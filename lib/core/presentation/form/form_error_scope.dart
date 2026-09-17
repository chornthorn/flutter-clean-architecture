import 'package:flutter/widgets.dart';

import 'form_error_controller.dart';

/// Scopes a [FormErrorController] to a subtree, enabling forms on the same
/// screen to manage validation errors independently without collision.
class FormErrorScope extends InheritedNotifier<FormErrorController> {
  const FormErrorScope({
    super.key,
    required FormErrorController controller,
    required super.child,
  }) : super(notifier: controller);

  /// Resolves the nearest [FormErrorController] in the widget tree, or null if none.
  static FormErrorController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<FormErrorScope>()
        ?.notifier;
  }

  /// Resolves the nearest [FormErrorController] in the widget tree.
  /// Throws an [AssertionError] in debug mode if not found.
  static FormErrorController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(
      controller != null,
      'No FormErrorScope found in the current BuildContext.',
    );
    return controller!;
  }
}
