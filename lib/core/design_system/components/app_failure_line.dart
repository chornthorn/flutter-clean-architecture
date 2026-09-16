import 'package:flutter/material.dart';

import '../app_theme.g.dart';

// A failure said in the flow of a screen, rather than in place of it — under a
// form's fields, or under the button whose call failed.
//
// The words stay in the reading colour and the icon carries the failure one: the
// danger token is a fill, and lands under text contrast on a light surface.
class AppFailureLine extends StatelessWidget {
  const AppFailureLine({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Row(
      children: [
        Icon(
          Icons.error_outline,
          size: theme.sizes.icon.md,
          color: theme.colors.feedback.danger,
        ),
        SizedBox(width: theme.sizes.spacing.sm),
        Expanded(
          child: Text(
            message,
            style: theme.typography.label.regular.copyWith(
              color: theme.colors.foreground.primary,
            ),
          ),
        ),
      ],
    );
  }
}
