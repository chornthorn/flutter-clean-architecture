// The body of a create request. Separate from `PostDto` because the request has
// no id — that one is the server's to assign, and sending a placeholder would be
// a lie in the payload.
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
