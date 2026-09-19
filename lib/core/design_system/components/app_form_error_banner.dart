import 'package:flutter/material.dart';

import '../app_theme.g.dart';

// The form-level failure a dialog shows when the write came back with no field
// to blame: one shape, so every form reports it the same way.
class AppFormErrorBanner extends StatelessWidget {
  const AppFormErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: theme.sizes.padding.sm,
        vertical: theme.sizes.padding.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colors.feedback.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(theme.sizes.radius.sm),
        border: Border.all(
          color: theme.colors.feedback.danger.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: theme.sizes.icon.sm,
            color: theme.colors.feedback.danger,
          ),
          SizedBox(width: theme.sizes.spacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.typography.label.regular.copyWith(
                color: theme.colors.feedback.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
