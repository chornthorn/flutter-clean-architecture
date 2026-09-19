import 'dart:io';

import '../model/kaisel_config.dart';
import '../model/library_scan.dart';
import 'provider.dart';
import 'spi.dart';

/// SPI: reading what a package declares.
class LibraryScannerSpi implements Spi<LibraryScanner> {
  const LibraryScannerSpi();

  /// The SPI as a session factory registers it.
  static const instance = LibraryScannerSpi();

  @override
  String get name => 'library-scanner';

  @override
  bool accepts(ProviderFactory<dynamic> factory) => factory is LibraryScannerFactory;
}

/// Reads everything Kaisel annotations declare under a package's `lib/`.
///
/// Implement this to read a package's sources from somewhere other than a `lib/`
/// directory on disk (a generated source set, an in-memory tree, a cache).
abstract interface class LibraryScanner implements Provider {
  /// Reads the modules, the `@KaiselInit` entry point and the micro-package
  /// declarations under [libDir] in one pass. A package with none of them is an
  /// empty scan, not an error.
  LibraryScan scan(Directory libDir);
}

/// Creates the [LibraryScanner] a session uses.
abstract interface class LibraryScannerFactory implements ProviderFactory<LibraryScanner> {}

/// SPI: reading the project around the sources.
class ProjectScannerSpi implements Spi<ProjectScanner> {
  const ProjectScannerSpi();

  /// The SPI as a session factory registers it.
  static const instance = ProjectScannerSpi();

  @override
  String get name => 'project-scanner';

  @override
  bool accepts(ProviderFactory<dynamic> factory) => factory is ProjectScannerFactory;
}

/// Reads a project's configuration and the `package:` config that names other
/// packages' files.
abstract interface class ProjectScanner implements Provider {
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

/// Creates the [ProjectScanner] a session uses.
abstract interface class ProjectScannerFactory implements ProviderFactory<ProjectScanner> {}
