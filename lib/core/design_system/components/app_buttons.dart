import 'package:flutter/material.dart';

import '../app_theme.g.dart';

// The app's three button weights, all painted from tokens.
//
// Material fills them from the generated scheme otherwise, so a `FilledButton`
// on its own would come out in a purple the token set never names — and would
// keep that colour through a mode change.

class AppFilledButton extends StatelessWidget {
  const AppFilledButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isEnabled = true,
    this.icon,
  });

  final String label;

  // Null means "no action wired yet"; [isEnabled] is the caller saying the
  // action exists but the data is not ready for it.
  final VoidCallback? onPressed;

  final bool isEnabled;

  // A leading glyph, for a button whose action an icon states faster than the
  // label does.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final onPressed = isEnabled ? this.onPressed : null;
    final style = FilledButton.styleFrom(
      backgroundColor: theme.colors.action.filled,
      foregroundColor: theme.colors.foreground.inverse,
    );

    if (icon case final icon?) {
      return FilledButton.icon(
        onPressed: onPressed,
        style: style,
        icon: Icon(icon),
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
    // control, and the brand pair is the app's only colour with the contrast to
    // carry it.
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
