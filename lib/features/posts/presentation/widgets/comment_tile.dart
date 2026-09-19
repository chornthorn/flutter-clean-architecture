import 'package:flutter/material.dart';

import '../../../../core/design_system/app_theme.g.dart';
import '../../../../core/design_system/components/app_card.dart';
import '../../domain/entities/comment.dart';

// One comment in a post's thread.
class CommentTile extends StatelessWidget {
  const CommentTile({super.key, required this.comment});

  final Comment comment;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  comment.name,
                  style: theme.typography.label.regular.copyWith(
                    color: theme.colors.foreground.primary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: theme.sizes.spacing.sm),
              // The address is context for the name, not content, so it is the
              // side of the row that gives way when the two do not fit.
              Flexible(
                child: Text(
                  comment.email,
                  style: theme.typography.label.regular,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          SizedBox(height: theme.sizes.spacing.sm),
          Text(comment.body, style: theme.typography.body.regular),
        ],
      ),
    );
  }
}
