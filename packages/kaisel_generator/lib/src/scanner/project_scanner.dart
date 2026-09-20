import '../model/kaisel_config.dart';

/// Reads a project's configuration and the `package:` config that names other
/// packages' files.
abstract interface class ProjectScanner {
  /// Reads `<root>/kaisel.yaml`, or returns `null` when the project has none.
  KaiselConfig? readConfig(String root);

  /// The `name:` of the package rooted at [root], or `null` when it has none.
  String? readPackageName(String root);

  /// Resolves the file an import URI names.
  ///
  /// `package:` imports resolve through the project's
  /// `.dart_tool/package_config.json`; relative imports resolve against the
  /// directory of the generated output file.
  String resolveImportUri({
    required String root,
    required String outputDir,
    required String importUri,
  });

  /// The `lib/` directory of a dependency package.
  String resolvePackageLibDir({required String root, required String package});
}
