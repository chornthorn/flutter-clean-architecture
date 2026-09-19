import '../../../../core/presentation/form/form_field_key.dart';

// `name` is also the enum constant below, so the key comes from the mixin,
// which reads the member's name off `Enum` rather than shadowing it.
enum CommentFormField with FormFieldKeyMixin {
  name,
  email,
  body;
}
