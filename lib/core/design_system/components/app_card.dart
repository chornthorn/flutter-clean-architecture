import 'package:flutter/material.dart';

import '../app_theme.g.dart';

// The surface a piece of content sits on: fill, hairline and padding from tokens,
// plus a ripple when the whole card is the tap target.
//
// A `Material` rather than a `Card`, because `Card` takes its colours from the
// generated scheme and would not follow the mode toggle.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.onTap});

  final Widget child;

  // Null for a card that only shows content.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Material(
      color: theme.colors.surface.card,
      // One shape draws the fill, the hairline and the ripple, so they cannot
      // drift apart.
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(theme.sizes.radius.md),
        side: BorderSide(color: theme.colors.surface.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(theme.sizes.padding.md),
          child: child,
        ),
      ),
    );
  }
}
