/// A zero-cost compile-time identifier for form fields backed by an [Enum].
///
/// Wraps [Enum] so that field keys cannot contain typos or arbitrary strings,
/// while compiling with zero runtime allocation overhead.
extension type const FormFieldKey(Enum field) implements Enum {
}
