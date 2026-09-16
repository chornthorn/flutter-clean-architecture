import 'package:flutter/material.dart';

import '../app_theme.g.dart';

// A screen with nothing to show, and why: nothing there yet, nothing found, or
// nothing reachable. One shape for all three keeps the states consistent — only
// the icon, the sentence and the colour differ.
class AppNotice extends StatelessWidget {
  const AppNotice({
    super.key,
    required this.icon,
    required this.message,
    this.isFailure = false,
    this.action,
  });

  final IconData icon;
  final String message;

  // A failure is worth the danger colour; an empty list is not a failure.
  final bool isFailure;

  // The way out of the state — retry, or write the first thing.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    // The danger token is sized for fills, not for text: on the light card it
    // lands around 3.8:1, under the 4.5:1 text needs. Here it colours the icon
    // only, where 3:1 is the bar it clears.
    final iconColor = isFailure
        ? theme.colors.feedback.danger
        : theme.colors.foreground.subtle;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          // Centred while it fits and scrollable once it does not: a large text
          // scale on a short screen is the case that would overflow. A parent
          // that offers no height to fill leaves the notice at its own size.
          constraints: BoxConstraints(
            minHeight: constraints.hasBoundedHeight ? constraints.maxHeight : 0,
          ),
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(theme.sizes.padding.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: theme.sizes.icon.lg, color: iconColor),
                  SizedBox(height: theme.sizes.spacing.md),
                  Text(
                    message,
                    style: theme.typography.body.regular,
                    textAlign: TextAlign.center,
                  ),
                  if (action case final action?) ...[
                    SizedBox(height: theme.sizes.spacing.md),
                    action,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
