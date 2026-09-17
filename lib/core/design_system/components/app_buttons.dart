import 'package:flutter/material.dart';

import '../app_theme.g.dart';

// The app's three button weights, all painted from tokens: Material would fill
// them from the generated scheme otherwise, and keep that colour through a mode
// change.

// Thin enough to read as a spinner at label size, where a full-weight ring
// reads as a hole punched in the button.
const _spinnerStrokeWidth = 2.0;

class AppFilledButton extends StatelessWidget {
  const AppFilledButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isEnabled = true,
    this.isLoading = false,
    this.icon,
  });

  final String label;

  // Null means no action is wired; [isEnabled] means it exists but the data is
  // not ready for it.
  final VoidCallback? onPressed;

  final bool isEnabled;

  // Work is in flight: the label stays put, the leading icon gives way to a
  // spinner, and the button holds its colour instead of greying out.
  final bool isLoading;

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    // Loading blocks presses like a disabled button, but it is not an
    // unavailable action — it is the action, running.
    final onPressed = isEnabled && !isLoading ? this.onPressed : null;
    final style = FilledButton.styleFrom(
      backgroundColor: theme.colors.action.filled,
      foregroundColor: theme.colors.foreground.inverse,
      disabledBackgroundColor: isLoading ? theme.colors.action.filled : null,
      disabledForegroundColor: isLoading
          ? theme.colors.foreground.inverse
          : null,
    );

    Widget? leading;
    if (isLoading) {
      leading = SizedBox.square(
        dimension: theme.sizes.icon.sm,
        child: CircularProgressIndicator(
          strokeWidth: _spinnerStrokeWidth,
          color: theme.colors.foreground.inverse,
        ),
      );
    } else if (icon case final icon?) {
      leading = Icon(icon);
    }

    if (leading case final leading?) {
      return FilledButton.icon(
        onPressed: onPressed,
        style: style,
        icon: leading,
        label: Text(label),
      );
    }

    return FilledButton(onPressed: onPressed, style: style, child: Text(label));
  }
}

class AppOutlinedButton extends StatelessWidget {
  const AppOutlinedButton({super.key, required this.label, this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    // Brand on both the outline and the label: the label is what identifies the
    // control, and the brand pair is the app's only colour with the contrast.
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: theme.colors.brand.primary,
        side: BorderSide(color: theme.colors.brand.primary),
      ),
      child: Text(label),
    );
  }
}

class AppTextButton extends StatelessWidget {
  const AppTextButton({super.key, required this.label, this.onPressed});

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
