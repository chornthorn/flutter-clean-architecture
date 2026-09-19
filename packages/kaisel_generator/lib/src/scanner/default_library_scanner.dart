import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:spi/spi.dart';

import '../model/init_info.dart';
import '../model/library_scan.dart';
import '../model/micro_package.dart';
import '../model/module_info.dart';
import '../spi/parser.dart';
import '../spi/scanner.dart';

/// The built-in [LibraryScanner]: walks a package's `lib/` on disk and reads
/// every annotation it names with the session's [AnnotationParser].
///
/// `*.g.dart` files are skipped. Their annotations belong to another generator,
/// and the registry this run writes is one of them — a scan that read it would
/// depend on its own output.
class DefaultLibraryScanner implements LibraryScanner {
  const DefaultLibraryScanner({required this.parser});

  final AnnotationParser parser;

  @override
  LibraryScan scan(Directory libDir) {
    final modules = <ModuleInfo>[];
    final microPackages = <MicroPackageDeclaration>[];
    InitInfo? init;
    var filesScanned = 0;
    var filesParsed = 0;

    for (final file in _dartSourcesIn(libDir)) {
      if (_isGenerated(file)) {
        continue;
      }
      filesScanned++;

      final source = _read(file);
      if (source == null) {
        continue;
      }

      var parsed = false;
      if (source.contains('KaiselModule')) {
        modules.addAll(parser.parseModules(file.path, source));
        parsed = true;
      }
      if (init == null && source.contains('KaiselInit')) {
        init = parser.parseInit(source);
        parsed = true;
      }
      if (source.contains('KaiselMicroPackage')) {
        final microPackage = parser.parseMicroPackage(file.path, source);
        if (microPackage != null) {
          microPackages.add(microPackage);
        }
        parsed = true;
      }
      if (parsed) {
        filesParsed++;
      }
    }

    return LibraryScan(
      modules: modules,
      init: init,
      microPackages: microPackages,
      filesScanned: filesScanned,
      filesParsed: filesParsed,
    );
  }

  @override
  void close() {}

  /// Every `.dart` source under [dir], in a stable order.
  ///
  /// Build output, VCS metadata and editor caches are never sources: a manifest
  /// under `build/` or `.dart_tool/` is a stale copy of one the package owns.
  Iterable<File> _dartSourcesIn(Directory dir) sync* {
    if (!dir.existsSync()) {
      return;
    }

    final entities = dir.listSync(followLinks: false)
      ..sort((a, b) => a.path.compareTo(b.path));

    for (final entity in entities) {
      final name = p.basename(entity.path);
      if (entity is Directory) {
        if (name.startsWith('.') || _skippedDirectories.contains(name)) {
          continue;
        }
        yield* _dartSourcesIn(entity);
      } else if (entity is File && name.endsWith('.dart')) {
        yield entity;
      }
    }
  }

  static bool _isGenerated(File file) => file.path.endsWith('.g.dart');

  static String? _read(File file) {
    try {
      return file.readAsStringSync();
    } on FileSystemException {
      return null;
    }
  }

  /// Directories that hold build output rather than a package's sources.
  static const _skippedDirectories = {'build', 'target'};
}

/// Creates the built-in [LibraryScanner], with the session's [AnnotationParser].
class DefaultLibraryScannerFactory implements LibraryScannerFactory {
  const DefaultLibraryScannerFactory();

  @override
  String get id => 'default';

  @override
  int get order => defaultProviderOrder;

  @override
  LibraryScanner create(ProviderSession session) => DefaultLibraryScanner(
        parser: session.provider(AnnotationParserSpi.instance),
      );
}
