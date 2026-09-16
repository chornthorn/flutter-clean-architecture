// The update body: no id (it is in the path), no author (an edit does not reassign).
class UpdatePostDto {
  const UpdatePostDto({required this.title, required this.body});

  final String title;
  final String body;

  Map<String, dynamic> toJson() => {'title': title, 'body': body};
}
