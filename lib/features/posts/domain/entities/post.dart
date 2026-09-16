// A post from the catalog at jsonplaceholder.typicode.com.
//
// Plain Dart: the shape a screen needs, not the shape the API returns — that
// mapping belongs in `infrastructure/`.
class Post {
  const Post({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
  });

  final int id;
  final int userId;
  final String title;
  final String body;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Post &&
          other.id == id &&
          other.userId == userId &&
          other.title == title &&
          other.body == body;

  @override
  int get hashCode => Object.hash(id, userId, title, body);

  @override
  String toString() => 'Post($id, $title)';
}
