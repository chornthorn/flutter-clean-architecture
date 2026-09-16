// The body of an update request: the fields a post can change. No id — that is
// in the path — and no author, because an edit does not reassign a post.
class UpdatePostDto {
  const UpdatePostDto({required this.title, required this.body});

  final String title;
  final String body;

  Map<String, dynamic> toJson() => {'title': title, 'body': body};
}
