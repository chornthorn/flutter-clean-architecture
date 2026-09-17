import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/post.dart';

part 'post_dto.g.dart';

// The wire shape of a post.
@JsonSerializable()
class PostDto {
  const PostDto({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
  });

  factory PostDto.fromJson(Map<String, dynamic> json) =>
      _$PostDtoFromJson(json);

  @JsonKey(name: 'id')
  final int id;

  @JsonKey(name: 'userId')
  final int userId;

  @JsonKey(name: 'title')
  final String title;

  @JsonKey(name: 'body')
  final String body;

  Map<String, dynamic> toJson() => _$PostDtoToJson(this);

  Post toDomain() => Post(id: id, userId: userId, title: title, body: body);
}
