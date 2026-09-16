import '../../domain/entities/post.dart';

// The wire shape of a post, hand-mapped: four flat fields are not worth a second generator.
class PostDto {
  const PostDto({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
  });

  factory PostDto.fromJson(Map<String, dynamic> json) => PostDto(
    id: json['id'] as int,
    userId: json['userId'] as int,
    title: json['title'] as String,
    body: json['body'] as String,
  );

  final int id;
  final int userId;
  final String title;
  final String body;

  Post toDomain() => Post(id: id, userId: userId, title: title, body: body);
}
