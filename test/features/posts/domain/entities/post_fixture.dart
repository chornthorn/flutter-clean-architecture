import 'package:flutter_x/features/posts/domain/entities/post.dart';

// The canonical post: it matches the in-memory adapter's first row, so ids stay consistent.
const post = Post(
  id: 1,
  userId: 1,
  title: 'First post',
  body: 'The first post in the local fixture.',
);
