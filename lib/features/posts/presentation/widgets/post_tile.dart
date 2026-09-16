import 'package:flutter/material.dart';

import '../../../../core/design_system/app_theme.g.dart';
import '../../domain/entities/post.dart';
import 'post_byline.dart';
import 'post_card.dart';

// One row in the post list: what the post says, clipped to two lines, and who
// wrote it. No routing, no data access — the page above decides what a tap
// means.
class PostTile extends StatelessWidget {
  const PostTile({super.key, required this.post, required this.onTap});

  final Post post;
  final VoidCallback onTap;

  // Smaller than the byline on the detail screen: here it is a caption beside
  // content, not the headline's companion.
  static const _badgeSize = 24.0;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return PostCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            post.title,
            style: theme.typography.title.regular,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: theme.sizes.spacing.sm),
          Text(
            post.body,
            style: theme.typography.label.regular,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: theme.sizes.spacing.md),
          Row(
            children: [
              PostByline(userId: post.userId, badgeSize: _badgeSize),
              const Spacer(),
              // Says there is more behind the row without adding a word to read.
              ExcludeSemantics(
                child: Icon(
                  Icons.chevron_right,
                  color: theme.colors.foreground.subtle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
