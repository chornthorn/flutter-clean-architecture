import 'package:json_annotation/json_annotation.dart';

part 'create_post_dto.g.dart';

// The create request body; no id, because the server assigns it.
@JsonSerializable()
class CreatePostDto {
  const CreatePostDto({
    required this.userId,
    required this.title,
    required this.body,
  });

  factory CreatePostDto.fromJson(Map<String, dynamic> json) =>
      _$CreatePostDtoFromJson(json);

  @JsonKey(name: 'userId')
  final int userId;

  @JsonKey(name: 'title')
  final String title;

  @JsonKey(name: 'body')
  final String body;

  Map<String, dynamic> toJson() => _$CreatePostDtoToJson(this);
}
