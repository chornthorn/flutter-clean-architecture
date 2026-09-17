import 'package:flutter/widgets.dart';

import 'app_form_controller.dart';
import 'app_form_provider.dart';

/// Bundles all original Flutter [Form] parameters into a single configuration object.
class AppFormOptions {
  const AppFormOptions({
    this.key,
    this.autovalidateMode = AutovalidateMode.disabled,
    this.onChanged,
    this.canPop,
    this.onPopInvokedWithResult,
  });

  /// Optional [GlobalKey] to override the form key. If null, [AppFormScope]
  /// automatically uses the [AppFormController.formKey].
  final GlobalKey<FormState>? key;

  /// Controls when client-side validators run on enclosed [FormField]s.
  final AutovalidateMode autovalidateMode;

  /// Called whenever any enclosed field's value changes.
  final VoidCallback? onChanged;

  /// Controls whether this form's route can be popped.
  final bool? canPop;

  /// Callback fired when a pop is invoked with result.
  final PopInvokedWithResultCallback<dynamic>? onPopInvokedWithResult;
}

/// A form-level scope widget built directly on top of Flutter's [Form].
///
/// Bundles:
/// 1. Native Flutter [Form] functionality (client validation, save, reset) via [options].
/// 2. Server-side error propagation via [controller] ([AppFormController]).
/// 3. Multiple-form isolation on a single screen via [AppFormProvider].
/// 4. Unified access to [FormState] directly via [controller.formKey] or [controller.validate].
class AppFormScope extends StatefulWidget {
  const AppFormScope({
    super.key,
    required this.child,
    this.controller,
    this.options = const AppFormOptions(),
  });

  /// The widget subtree containing form fields.
  final Widget child;

  /// Optional form controller. If omitted, an internal controller
  /// is created and disposed automatically with the scope.
  final AppFormController? controller;

  /// All original Flutter [Form] options grouped cleanly under this field.
  final AppFormOptions options;

  /// Retrieves the Flutter [FormState] from the nearest [AppFormScope].
  static FormState of(BuildContext context) => Form.of(context);

  /// Retrieves the Flutter [FormState], or null if not found.
  static FormState? maybeOf(BuildContext context) => Form.maybeOf(context);

  /// Retrieves the [AppFormController] from the nearest [AppFormProvider].
  static AppFormController? controllerOf(BuildContext context) =>
      AppFormProvider.maybeOf(context);

  @override
  State<AppFormScope> createState() => _AppFormScopeState();
}

class _AppFormScopeState extends State<AppFormScope> {
  late AppFormController _controller;
  late GlobalKey<FormState> _formKey;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    _initController();
    _formKey = widget.options.key ?? _controller.formKey;
  }

  void _initController() {
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      _controller = AppFormController();
      _ownsController = true;
    }
  }

  @override
  void didUpdateWidget(AppFormScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      if (_ownsController) {
        _controller.dispose();
      }
      _initController();
    }
    _formKey = widget.options.key ?? _controller.formKey;
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: widget.options.autovalidateMode,
      onChanged: widget.options.onChanged,
      canPop: widget.options.canPop,
      onPopInvokedWithResult: widget.options.onPopInvokedWithResult,
      child: AppFormProvider(
        controller: _controller,
        child: widget.child,
      ),
    );
  }
}
