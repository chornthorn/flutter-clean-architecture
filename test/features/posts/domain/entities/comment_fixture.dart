import 'package:flutter_x/features/posts/domain/entities/comment.dart';

// The canonical comment: it matches the in-memory adapter's first row, so ids
// stay consistent.
const comment = Comment(
  id: 1,
  postId: 1,
  name: 'Ada Lovelace',
  email: 'ada@example.com',
  body: 'The first comment on the first post.',
);
