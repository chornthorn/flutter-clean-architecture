import 'package:flutter/material.dart';

import '../../../../core/design_system/app_theme.g.dart';
import '../../../../core/design_system/components/app_buttons.dart';
import '../../../../core/design_system/components/app_failure_line.dart';
import '../../../../core/presentation/action_result.dart';

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
  bool _isSubmitting = false;
  String? _errorMessage;
  Map<String, String> _fieldErrors = const {};

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _fieldErrors = const {};
    });

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
        _errorMessage = result.message;
        _fieldErrors = result.fieldErrors;
      } else {
        _errorMessage = 'Could not save the post.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return AlertDialog(
      backgroundColor: theme.colors.surface.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(theme.sizes.radius.md),
      ),
      title: Text(widget.heading, style: theme.typography.title.semiBold),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            style: theme.typography.body.regular,
            cursorColor: theme.colors.brand.primary,
            decoration: _fieldDecoration(
              theme,
              'Title',
              errorText: _fieldErrors['title'],
            ),
          ),
          SizedBox(height: theme.sizes.spacing.md),
          TextField(
            controller: _body,
            style: theme.typography.body.regular,
            cursorColor: theme.colors.brand.primary,
            decoration: _fieldDecoration(
              theme,
              'Body',
              errorText: _fieldErrors['body'],
            ),
          ),
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
    );
  }

  // `InputDecoration` would otherwise take its outline and focus colours from the scheme.
  InputDecoration _fieldDecoration(
    AppTheme theme,
    String label, {
    String? errorText,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(theme.sizes.radius.md),
      borderSide: BorderSide(color: theme.colors.surface.border),
    );

    return InputDecoration(
      labelText: label,
      errorText: errorText,
      labelStyle: theme.typography.label.regular,
      floatingLabelStyle: theme.typography.label.regular.copyWith(
        color: theme.colors.brand.primary,
      ),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: theme.colors.brand.primary, width: 2),
      ),
    );
  }
}
