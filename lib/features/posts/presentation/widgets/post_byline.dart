import 'package:flutter/material.dart';

import '../../../../core/design_system/app_theme.g.dart';
import 'post_author_badge.dart';

// Who wrote a post, as one unit: the badge and the line of text that names it.
// Sits under a title in the list and above the body on the detail screen, so it
// sizes the badge per call site rather than hardcoding one.
class PostByline extends StatelessWidget {
  const PostByline({super.key, required this.userId, this.badgeSize = 32});

  final int userId;
  final double badgeSize;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PostAuthorBadge(size: badgeSize),
        SizedBox(width: theme.sizes.spacing.sm),
        Text('by user $userId', style: theme.typography.label.regular),
      ],
    );
  }
}
