import 'package:flutter/material.dart';

import '../../../../core/design_system/app_theme.g.dart';

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
    return AlertDialog(
      title: Text(widget.heading),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          TextField(
            controller: _body,
            decoration: const InputDecoration(labelText: 'Body'),
          ),
          if (_failed) ...[
            SizedBox(height: context.theme.sizes.spacing.md),
            const Text('Could not save the post.'),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        // A title the domain will reject is not worth a round trip to say so.
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _title,
          builder: (context, value, _) => FilledButton(
            onPressed: _isSubmitting || value.text.trim().isEmpty
                ? null
                : _submit,
            child: Text(widget.submitLabel),
          ),
        ),
      ],
    );
  }
}
