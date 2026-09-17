/// Converts camelCase or PascalCase to snake_case (e.g. `isAvailable` -> `is_available`).
String formFieldKeyToSnakeCase(String input) {
  return input
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match.group(1)}_${match.group(2)!.toLowerCase()}',
      )
      .toLowerCase();
}

/// Converts snake_case to camelCase (e.g. `is_available` -> `isAvailable`).
String formFieldKeyToCamelCase(String input) {
  return input.replaceAllMapped(
    RegExp(r'_([a-zA-Z])'),
    (match) => match.group(1)!.toUpperCase(),
  );
}

/// Base contract that all form field key types (enums or classes) must implement.
abstract interface class FormFieldKeyBase {
  /// The wire key matching backend error responses (e.g. 'is_available', 'post_title').
  String get key;
}

/// A raw string implementation of [FormFieldKeyBase].
final class RawFormFieldKey implements FormFieldKeyBase {
  const RawFormFieldKey(this.key);

  @override
  final String key;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RawFormFieldKey && other.key == key ||
      other is FormFieldKeyBase && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// Optional mixin for enums implementing [FormFieldKeyBase] that default [key] to [Enum.name].
mixin FormFieldKeyMixin on Enum implements FormFieldKeyBase {
  @override
  String get key => name;
}

/// Optional mixin for enums implementing [FormFieldKeyBase] that automatically converts
/// the enum member's camelCase [Enum.name] to snake_case (e.g. `isAvailable` -> `is_available`).
mixin SnakeCaseFormFieldKeyMixin on Enum implements FormFieldKeyBase {
  @override
  String get key => formFieldKeyToSnakeCase(name);
}

/// A zero-cost compile-time identifier for form fields backed by [FormFieldKeyBase].
///
/// Wraps [FormFieldKeyBase] so that only types explicitly implementing
/// [FormFieldKeyBase] can be used as form field keys.
extension type const FormFieldKey(FormFieldKeyBase field)
    implements FormFieldKeyBase {
  /// Creates a form field key from a raw string [key].
  factory FormFieldKey.raw(String key) => FormFieldKey(RawFormFieldKey(key));

  /// Backwards-compatible alias for [key].
  String get name => field.key;

  /// The snake_case representation of [key] (e.g. `isAvailable` -> `is_available`).
  String get snakeCase => formFieldKeyToSnakeCase(field.key);

  /// The camelCase representation of [key] (e.g. `is_available` -> `isAvailable`).
  String get camelCase => formFieldKeyToCamelCase(field.key);
}
