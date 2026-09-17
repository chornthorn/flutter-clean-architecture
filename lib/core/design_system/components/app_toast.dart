import 'package:flutter/material.dart';

import '../app_theme.g.dart';

/// Toast and alert messenger that renders transient notifications matching
/// the app design tokens.
abstract final class AppToast {
  /// Shows a success feedback toast.
  static void showSuccess(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.check_circle_outline,
      iconColor: (theme) => theme.colors.feedback.success,
    );
  }

  /// Shows an error feedback toast.
  static void showError(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.error_outline,
      iconColor: (theme) => theme.colors.feedback.danger,
    );
  }

  /// Shows an informational feedback toast.
  static void showInfo(BuildContext context, String message) {
    _show(
      context,
      message: message,
      icon: Icons.info_outline,
      iconColor: (theme) => theme.colors.foreground.subtle,
    );
  }

  static void _show(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color Function(AppTheme theme) iconColor,
  }) {
    final theme = context.theme;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.all(theme.sizes.padding.md),
        padding: EdgeInsets.zero,
        content: Container(
          padding: EdgeInsets.symmetric(
            horizontal: theme.sizes.padding.md,
            vertical: theme.sizes.padding.sm,
          ),
          decoration: BoxDecoration(
            color: theme.colors.surface.card,
            borderRadius: BorderRadius.circular(theme.sizes.radius.md),
            border: Border.all(color: theme.colors.surface.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor(theme), size: theme.sizes.icon.md),
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
          ),
        ),
      ),
    );
  }
}
