import 'package:flutter_x/features/posts/domain/entities/post.dart';

// The canonical post tests build on, so ids stay consistent across files. It
// matches the in-memory adapter's first row.
const post = Post(
  id: 1,
  userId: 1,
  title: 'First post',
  body: 'The first post in the local fixture.',
);
