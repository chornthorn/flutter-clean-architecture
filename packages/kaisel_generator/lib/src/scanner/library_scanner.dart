import 'dart:io';

import 'package:path/path.dart' as p;

import '../model/init_info.dart';
import '../model/micro_package.dart';
import '../model/module_info.dart';
import '../parser/annotation_parser.dart';

/// Reusable walker over a package's `lib/`, handing each candidate file to
/// [AnnotationParser].
///
/// `*.g.dart` files are skipped: their annotations belong to another generator,
/// and the registry this run writes is one of them — a scan that read it would
/// depend on its own output.
class LibraryScanner {
  const LibraryScanner({this.parser = const AnnotationParser()});

  final AnnotationParser parser;

  /// Reads every `@KaiselModule` under [libDir].
  ModuleScanResult scanModules(Directory libDir) {
    final modules = <ModuleInfo>[];
    var filesScanned = 0;
    var filesParsed = 0;

    for (final file in dartSourcesIn(libDir)) {
      if (_isGenerated(file)) {
        continue;
      }
      filesScanned++;

      final source = _read(file);
      if (source == null || !source.contains('KaiselModule')) {
        continue;
      }
      filesParsed++;

      modules.addAll(parser.parseModules(file.path, source));
    }

    return ModuleScanResult(
      modules: modules,
      filesScanned: filesScanned,
      filesParsed: filesParsed,
    );
  }

  /// The first `@KaiselInit` configuration under [libDir], or `null`.
  InitInfo? findInit(Directory libDir) {
    for (final candidate in _candidates(libDir, 'KaiselInit')) {
      final init = parser.parseInit(candidate.source);
      if (init != null) {
        return init;
      }
    }
    return null;
  }

  /// Every `@KaiselMicroPackage` declaration under [libDir].
  List<MicroPackageDeclaration> findMicroPackages(Directory libDir) {
    final found = <MicroPackageDeclaration>[];
    for (final candidate in _candidates(libDir, 'KaiselMicroPackage')) {
      final microPackage = parser.parseMicroPackage(candidate.file.path, candidate.source);
      if (microPackage != null) {
        found.add(microPackage);
      }
    }
    return found;
  }

  /// Every `.dart` source under [dir], in a stable order.
  ///
  /// Build output, VCS metadata and editor caches are never sources: a manifest
  /// under `build/` or `.dart_tool/` is a stale copy of one the package owns.
  Iterable<File> dartSourcesIn(Directory dir) sync* {
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
        yield* dartSourcesIn(entity);
      } else if (entity is File && name.endsWith('.dart')) {
        yield entity;
      }
    }
  }

  /// Files that carry an annotation, cheapest check first: the parser only runs
  /// on a file whose text names the annotation at all.
  Iterable<({File file, String source})> _candidates(
    Directory libDir,
    String annotation,
  ) sync* {
    for (final file in dartSourcesIn(libDir)) {
      if (_isGenerated(file)) {
        continue;
      }
      final source = _read(file);
      if (source != null && source.contains(annotation)) {
        yield (file: file, source: source);
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
