import 'package:flutter/material.dart';

import '../../../../core/design_system/app_theme.g.dart';
import '../../../../core/design_system/components/app_buttons.dart';
import '../../../../core/design_system/components/app_failure_line.dart';

// Collects a post and hands it to the page, which owns the write call — so this
// widget needs no view model and can be tested on its own.
//
// One form serves create and edit; what differs is the wording and the text the
// fields start with.
//
// It stays open while the call is in flight, and on failure says so instead of
// closing and losing what was typed.
class PostFormDialog extends StatefulWidget {
  const PostFormDialog({
    super.key,
    required this.heading,
    required this.submitLabel,
    required this.onSubmit,
    this.initialTitle = '',
    this.initialBody = '',
  });

  // The dialog's own title: 'New post' or 'Edit post'.
  final String heading;

  final String submitLabel;

  // Answers whether the write worked.
  final Future<bool> Function(String title, String body) onSubmit;

  final String initialTitle;
  final String initialBody;

  @override
  State<PostFormDialog> createState() => _PostFormDialogState();
}

class _PostFormDialogState extends State<PostFormDialog> {
  late final _title = TextEditingController(text: widget.initialTitle);
  late final _body = TextEditingController(text: widget.initialBody);
  bool _isSubmitting = false;
  bool _failed = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _failed = false;
    });

    final saved = await widget.onSubmit(_title.text, _body.text);

    // The page can be gone by now if the dialog was dismissed mid-flight.
    if (!mounted) return;

    if (saved) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _isSubmitting = false;
      _failed = true;
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
            decoration: _fieldDecoration(theme, 'Title'),
          ),
          SizedBox(height: theme.sizes.spacing.md),
          TextField(
            controller: _body,
            style: theme.typography.body.regular,
            cursorColor: theme.colors.brand.primary,
            decoration: _fieldDecoration(theme, 'Body'),
          ),
          if (_failed) ...[
            SizedBox(height: theme.sizes.spacing.md),
            const AppFailureLine(message: 'Could not save the post.'),
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

  // The field's own chrome, since `InputDecoration` would otherwise take its
  // outline and focus colours from the generated scheme.
  InputDecoration _fieldDecoration(AppTheme theme, String label) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(theme.sizes.radius.md),
      borderSide: BorderSide(color: theme.colors.surface.border),
    );

    return InputDecoration(
      labelText: label,
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
