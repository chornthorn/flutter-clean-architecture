import '../../../../core/error/app_exception.dart';

// A post from the catalog at jsonplaceholder.typicode.com.
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

// The one title rule; it lives with the entity so create and update cannot drift.
String cleanedTitle(String title) {
  final cleaned = title.trim();
  if (cleaned.isEmpty) {
    throw const ValidationException(
      message: 'A post needs a title.',
      fieldErrors: {'title': 'A post needs a title'},
    );
  }
  return cleaned;
}
