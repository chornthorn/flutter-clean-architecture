import 'package:flutter/material.dart';

import '../../domain/entities/post.dart';

// One row in the post list. No routing, no data access — the page above decides
// what a tap means.
class PostTile extends StatelessWidget {
  const PostTile({super.key, required this.post, required this.onTap});

  final Post post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(post.title),
      subtitle: Text('by user ${post.userId}'),
      onTap: onTap,
    );
  }
}
