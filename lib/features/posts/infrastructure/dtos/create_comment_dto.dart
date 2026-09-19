import 'package:json_annotation/json_annotation.dart';

part 'create_comment_dto.g.dart';

// The create request body; no id, because the server assigns it.
@JsonSerializable()
class CreateCommentDto {
  const CreateCommentDto({
    required this.postId,
    required this.name,
    required this.email,
    required this.body,
  });

  factory CreateCommentDto.fromJson(Map<String, dynamic> json) =>
      _$CreateCommentDtoFromJson(json);

  @JsonKey(name: 'postId')
  final int postId;

  @JsonKey(name: 'name')
  final String name;

  @JsonKey(name: 'email')
  final String email;

  @JsonKey(name: 'body')
  final String body;

  Map<String, dynamic> toJson() => _$CreateCommentDtoToJson(this);
}
