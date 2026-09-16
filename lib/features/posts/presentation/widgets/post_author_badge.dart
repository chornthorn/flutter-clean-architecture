import 'package:flutter/material.dart';

import '../../../../core/design_system/app_theme.g.dart';

// The mark that stands in for an author's avatar, which the catalog has no data
// for. Decorative: the byline beside it already says who wrote the post.
class PostAuthorBadge extends StatelessWidget {
  const PostAuthorBadge({super.key, this.size = 32});

  final double size;

  // No token covers this ratio — it is the badge's own proportion.
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
