import 'package:flutter/material.dart';

import '../../../../core/design_system/app_theme.g.dart';

// The mark that stands in for an author's avatar, which the catalog has no data
// for. Its colour pair is the brand container/primary one, so it reads the same
// in both modes.
//
// Decorative on purpose: the byline beside it already says who wrote the post,
// so announcing it too would only repeat itself.
class PostAuthorBadge extends StatelessWidget {
  const PostAuthorBadge({super.key, this.size = 32});

  final double size;

  // A glyph at roughly half the disc reads as a mark rather than a squeezed
  // icon. No token covers this ratio — it is the badge's own proportion.
  static const _glyphRatio = 0.55;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: theme.colors.brand.container,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.person_outline,
          size: size * _glyphRatio,
          color: theme.colors.brand.primary,
        ),
      ),
    );
  }
}
