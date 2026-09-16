// The create request body; no id, because the server assigns it.
class CreatePostDto {
  const CreatePostDto({
    required this.userId,
    required this.title,
    required this.body,
  });

  final int userId;
  final String title;
  final String body;

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'title': title,
    'body': body,
  };
}
