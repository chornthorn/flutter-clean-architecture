import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/comment.dart';

part 'comment_dto.g.dart';

// The wire shape of a comment.
@JsonSerializable()
class CommentDto {
  const CommentDto({
    required this.id,
    required this.postId,
    required this.name,
    required this.email,
    required this.body,
  });

  factory CommentDto.fromJson(Map<String, dynamic> json) =>
      _$CommentDtoFromJson(json);

  @JsonKey(name: 'id')
  final int id;

  @JsonKey(name: 'postId')
  final int postId;

  @JsonKey(name: 'name')
  final String name;

  @JsonKey(name: 'email')
  final String email;

  @JsonKey(name: 'body')
  final String body;

  Map<String, dynamic> toJson() => _$CommentDtoToJson(this);

  Comment toDomain() => Comment(
    id: id,
    postId: postId,
    name: name,
    email: email,
    body: body,
  );
}
