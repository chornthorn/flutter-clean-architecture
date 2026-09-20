import 'dart:io';

import '../model/library_scan.dart';

/// Reads everything Kaisel annotations declare under a package's `lib/`.
///
/// The generator's default reads a directory on disk; a test that needs a fixture
/// implements this instead.
abstract interface class LibraryScanner {
  /// Reads the modules, the `@KaiselInit` entry point and the micro-package
  /// declarations under [libDir] in one pass. A package with none of them is an
  /// empty scan, not an error.
  LibraryScan scan(Directory libDir);
}
