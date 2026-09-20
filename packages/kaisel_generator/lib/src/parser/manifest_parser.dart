import '../model/micro_package.dart';

/// Reads the mounts a generated manifest declares.
abstract interface class ManifestParser {
  /// Reads the manifest [source] declares, or `null` when it was not produced by
  /// a compatible generator — the caller then reports that the manifest must be
  /// regenerated rather than composing a package that would silently contribute
  /// no mounts.
  MicroPackageManifest? parse(String source);
}
