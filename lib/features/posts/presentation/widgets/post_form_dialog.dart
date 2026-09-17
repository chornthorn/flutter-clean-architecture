import 'package:flutter/material.dart';

import '../../../../core/design_system/app_theme.g.dart';
import '../../../../core/design_system/components/app_buttons.dart';
import '../../../../core/design_system/components/app_failure_line.dart';
import '../../../../core/design_system/components/app_text_field.dart';
import '../../../../core/presentation/action_result.dart';
import '../../../../core/presentation/form/app_form_controller.dart';
import '../../../../core/presentation/form/app_form_scope.dart';

// Collects a post and hands it to the page, which owns the write call.
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

  // Answers the result of the write: success or failure message/fields.
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
      options: const .options(autovalidateMode: .onUserInteraction),
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
              AppFailureLine(message: _errorMessage!),
            ],
          ],
        ),
        actions: [
          AppTextButton(
            label: 'Cancel',
            onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          ),
          // A title the domain will reject is not worth a round trip to say so.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _title,
            builder: (context, value, _) => AppFilledButton(
              label: widget.submitLabel,
              isEnabled: !_isSubmitting && value.text.trim().isNotEmpty,
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }
}
