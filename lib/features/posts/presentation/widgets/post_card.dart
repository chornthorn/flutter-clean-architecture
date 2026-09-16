import 'package:flutter/material.dart';

import '../../../../core/design_system/app_theme.g.dart';

// The surface a post sits on: fill, hairline and padding from tokens.
//
// It is a `Material` rather than a `Card` because `Card` takes its colours from
// Material's generated scheme, which the token theme does not supply — a card
// drawn that way would not follow the mode toggle.
class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.child, this.onTap});

  final Widget child;

  // Null for a card that only shows content, as the detail body does.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final radius = BorderRadius.circular(theme.sizes.radius.md);

    return Material(
      color: theme.colors.surface.card,
      // One shape draws the fill, the hairline and the ink ripple, so they
      // cannot drift apart.
      shape: RoundedRectangleBorder(
        borderRadius: radius,
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
