/// What one scan of a package's `lib/` found.
///
/// A plain value read from source, so it can be asserted on without a build: the
/// scan needs an AST, never a resolved program.
library;

import 'init_info.dart';
import 'micro_package.dart';
import 'module_info.dart';

/// Everything Kaisel annotations declare under a package's `lib/`.
class LibraryScan {
  const LibraryScan({
    required this.modules,
    required this.microPackages,
    required this.filesScanned,
    required this.filesParsed,
    this.init,
  });

  /// Every `@KaiselModule` class, in file order.
  final List<ModuleInfo> modules;

  /// The `@KaiselInit` entry point, when the package declares one.
  final InitInfo? init;

  /// Every `@KaiselMicroPackage` declaration, in file order. A package generates
  /// one manifest, from the first one.
  final List<MicroPackageDeclaration> microPackages;

  /// `.dart` files the walk considered.
  final int filesScanned;

  /// Files that named a Kaisel annotation and were therefore parsed.
  final int filesParsed;
}
