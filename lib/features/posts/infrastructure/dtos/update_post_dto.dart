import 'package:json_annotation/json_annotation.dart';

part 'update_post_dto.g.dart';

// The update body: no id (it is in the path), no author (an edit does not reassign).
@JsonSerializable()
class UpdatePostDto {
  const UpdatePostDto({required this.title, required this.body});

  factory UpdatePostDto.fromJson(Map<String, dynamic> json) =>
      _$UpdatePostDtoFromJson(json);

  @JsonKey(name: 'title')
  final String title;

  @JsonKey(name: 'body')
  final String body;

  Map<String, dynamic> toJson() => _$UpdatePostDtoToJson(this);
}
