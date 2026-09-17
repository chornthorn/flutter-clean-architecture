import 'package:flutter/material.dart';

import '../../../../core/design_system/app_theme.g.dart';
import '../../../../core/design_system/components/app_text_field.dart';
import '../../../../core/presentation/action_result.dart';
import '../../../../core/presentation/form/app_form_controller.dart';
import '../../../../core/presentation/form/app_form_scope.dart';

/// Modal dialog for creating or editing a post.
///
/// Features:
/// - Uses [AppFormScope] and [AppFormController] to integrate client-side
///   validation and server-side field error mappings.
/// - Demonstrates form-level [AppFormOptions] with `autovalidateMode: AutovalidateMode.onUserInteraction`.
/// - Leverages design system [AppTextField] components with automated error styling.
class PostFormDialog extends StatefulWidget {
  const PostFormDialog({
    super.key,
    required this.heading,
    required this.submitLabel,
    required this.onSubmit,
    this.initialTitle = '',
    this.initialBody = '',
  });

  final String heading;
  final String submitLabel;
  final Future<ActionResult> Function(String title, String body) onSubmit;
  final String initialTitle;
  final String initialBody;

  @override
  State<PostFormDialog> createState() => _PostFormDialogState();
}

class _PostFormDialogState extends State<PostFormDialog> {
  late final _title = TextEditingController(text: widget.initialTitle);
  late final _body = TextEditingController(text: widget.initialBody);
  late final _form = AppFormController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _form.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Validates directly via the form controller's formKey
    if (!_form.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    _form.clear();

    final result = await widget.onSubmit(_title.text, _body.text);

    // The page can be gone by now if the dialog was dismissed mid-flight.
    if (!mounted) return;

    if (result.isSuccess) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isSubmitting = false;
      if (result is ActionFailure) {
        _errorMessage = result.fieldErrors.isEmpty ? result.message : null;
        _form.bind(result);
      } else {
        _errorMessage = 'Could not save the post.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return AppFormScope(
      controller: _form,
      options: const .options(autovalidateMode: AutovalidateMode.onUserInteraction),
      child: AlertDialog(
        backgroundColor: theme.colors.surface.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(theme.sizes.radius.md),
        ),
        title: Text(widget.heading, style: theme.typography.title.semiBold),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              fieldKey: 'title',
              controller: _title,
              label: 'Title',
              validator: (value) {
                // keep it here is I want to demo both client and server validation
                if (value == null || value.trim().length < 5) {
                  return 'Title must be at least 5 characters.';
                }
                return null;
              },
            ),
            SizedBox(height: theme.sizes.spacing.md),
            AppTextField(fieldKey: 'body', controller: _body, label: 'Body'),
            if (_errorMessage != null) ...[
              SizedBox(height: theme.sizes.spacing.md),
              Text(
                _errorMessage!,
                style: theme.typography.body.regular.copyWith(
                  color: theme.colors.feedback.danger,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
            child: Text('Cancel', style: theme.typography.body.regular),
          ),
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.submitLabel, style: theme.typography.body.regular),
          ),
        ],
      ),
    );
  }
}
