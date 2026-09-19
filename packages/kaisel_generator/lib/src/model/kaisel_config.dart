/// The configuration a project's `kaisel.yaml` may set.
///
/// A `kaisel.yaml` is optional — a project that configures everything through
/// `@KaiselInit` needs none — but when the file is there it is read as YAML, so
/// quotes, comments and key order behave the way a reader expects.
library;

/// The keys `kaisel.yaml` may set.
class KaiselConfig {
  const KaiselConfig({
    this.output,
    this.routeClass,
    this.initialRoute,
    this.libDir,
  });

  /// Path of the generated registry, relative to the project root.
  final String? output;

  /// Name of the host's sealed route class.
  final String? routeClass;

  /// Mount the host lands on, overriding `isInitial`.
  final String? initialRoute;

  /// Directory to scan, relative to the project root.
  final String? libDir;
}
