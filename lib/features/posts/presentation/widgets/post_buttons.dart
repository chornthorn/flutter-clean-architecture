import 'package:flutter/material.dart';

import '../../../../core/design_system/app_theme.g.dart';

// The two button flavours the post screens use, both painted from tokens.
//
// Material fills them from the generated scheme otherwise, so a `FilledButton`
// on its own would come out in a purple the token set never names — and would
// keep that colour through a mode change.

class PostFilledButton extends StatelessWidget {
  const PostFilledButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isEnabled = true,
  });

  final String label;

  // Null means "no action wired yet"; [isEnabled] is the caller saying the
  // action exists but the data is not ready for it.
  final VoidCallback? onPressed;

  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return FilledButton(
      onPressed: isEnabled ? onPressed : null,
      style: FilledButton.styleFrom(
        backgroundColor: theme.colors.action.filled,
        foregroundColor: theme.colors.foreground.inverse,
      ),
      child: Text(label),
    );
  }
}

class PostTextButton extends StatelessWidget {
  const PostTextButton({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(foregroundColor: theme.colors.brand.primary),
      child: Text(label),
    );
  }
}
