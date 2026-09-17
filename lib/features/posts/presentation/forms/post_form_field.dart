import '../../../../core/presentation/form/form_field_key.dart';

enum PostFormField implements FormFieldKeyBase {
  title,
  body;

  @override
  String get key => name;
}
