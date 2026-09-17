import 'package:flutter/material.dart';

import '../../../../core/design_system/app_theme.g.dart';
import '../../../../core/design_system/components/app_buttons.dart';
import '../../../../core/design_system/components/app_text_field.dart';
import '../../../../core/presentation/action_result.dart';
import '../../../../core/presentation/form/app_form_scope.dart';

/// Form fields for [PostFormDialog], implementing [FormFieldKeyBase].
enum PostFormField with FormFieldKeyMixin {
  title,
  body;
}

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
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  final _formController = AppFormController();
  late String _title;
  var _submitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _title = widget.initialTitle;
    _titleController = TextEditingController(text: widget.initialTitle)
      ..addListener(() {
        if (_title != _titleController.text) {
          setState(() => _title = _titleController.text);
        }
      });
    _bodyController = TextEditingController(text: widget.initialBody);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _formController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final formValid = _formController.validate();
    if (!formValid) {
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    final result = await widget.onSubmit(
      _titleController.text.trim(),
      _bodyController.text.trim(),
    );

    if (!mounted) return;

    if (result is ActionFailure) {
      setState(() {
        _submitting = false;
        _errorMessage = result.fieldErrors.isEmpty ? result.message : null;
      });
      _formController.bind(result);
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return AlertDialog(
      title: Text(widget.heading),
      content: SingleChildScrollView(
        child: AppFormScope(
          controller: _formController,
          options: const AppFormOptions(
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_errorMessage case final message?) ...[
                Text(
                  message,
                  style: theme.typography.body.regular.copyWith(
                    color: theme.colors.feedback.danger,
                  ),
                ),
                SizedBox(height: theme.sizes.spacing.md),
              ],
              AppTextField(
                fieldKey: const FormFieldKey(PostFormField.title),
                controller: _titleController,
                label: 'Title',
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.length < 5) {
                    return 'Title must be at least 5 characters.';
                  }
                  return null;
                },
              ),
              SizedBox(height: theme.sizes.spacing.md),
              AppTextField(
                fieldKey: const FormFieldKey(PostFormField.body),
                controller: _bodyController,
                label: 'Body',
                maxLines: 4,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed:
              _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        AppFilledButton(
          label: widget.submitLabel,
          isEnabled: _title.trim().isNotEmpty && !_submitting,
          onPressed: _submit,
        ),
      ],
    );
  }
}
