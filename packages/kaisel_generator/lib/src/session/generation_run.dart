import 'dart:io';

import 'package:path/path.dart' as p;

import '../emitter/default_import_emitter.dart';
import '../emitter/default_manifest_emitter.dart';
import '../emitter/default_registry_emitter.dart';
import '../emitter/import_emitter.dart';
import '../emitter/manifest_emitter.dart';
import '../emitter/registry_emitter.dart';
import '../generation/generation.dart';
import '../model/library_scan.dart';
import '../model/module_info.dart';
import '../model/project_context.dart';
import '../parser/default_annotation_parser.dart';
import '../parser/default_manifest_parser.dart';
import '../parser/manifest_parser.dart';
import '../scanner/default_library_scanner.dart';
import '../scanner/default_project_scanner.dart';
import '../scanner/library_scanner.dart';
import '../scanner/project_scanner.dart';

/// One generation run: the resolved project, the scan of its sources, the request
/// built from both, and the stages that produce the output.
///
/// Each stage is created on first use and reused for the rest of the run, so one
/// run parses its sources once and writes every file it needs from that one scan.
final class GenerationRun {
  GenerationRun({this.root, this.libDir, this.output, this.write = true});

  /// Project root the run was asked for, or `null` to find the nearest one.
  final String? root;

  /// Directory to scan, or `null` to take `kaisel.yaml`'s or `lib/`.
  final String? libDir;

  /// Path of the output file, or `null` to take the configured or conventional
  /// one.
  final String? output;

  /// Whether the caller wants the output written, or its source handed back.
  final bool write;

  /// Reads `kaisel.yaml`, `pubspec.yaml` and the package config.
  late final ProjectScanner projectScanner = const DefaultProjectScanner();

  /// Reads the annotations of one package's `lib/`.
  late final LibraryScanner libraryScanner = DefaultLibraryScanner(
    parser: const DefaultAnnotationParser(),
  );

  /// Reads a generated manifest's mounts back.
  late final ManifestParser manifestParser = const DefaultManifestParser();

  /// Writes the imports a generated file opens with.
  late final ImportEmitter importEmitter = const DefaultImportEmitter();

  /// Writes the host's registry.
  late final RegistryEmitter registryEmitter = DefaultRegistryEmitter(
    imports: importEmitter,
  );

  /// Writes a micro-package's manifest.
  late final ManifestEmitter manifestEmitter = DefaultManifestEmitter(
    imports: importEmitter,
  );

  ProjectContext? _project;
  LibraryScan? _scan;
  GenerationRequest? _request;

  /// The project this run works against, with its configuration resolved.
  ProjectContext get project => _project ??= _resolveProject();

  /// What the scan of the project's sources found.
  LibraryScan get scan {
    project; // Resolving the project resolves the scan with it.
    return _scan!;
  }

  /// What the generation is asked to produce.
  GenerationRequest get request => _request ??= GenerationRequest(
    root: project.root,
    libDir: project.libDir,
    outputPath: project.outputPath,
    modules: sortModules(scan.modules),
    packageName: project.packageName,
    config: project.config,
    init: scan.init,
    write: project.write,
  );

  ProjectContext _resolveProject() {
    final projectRoot = p.normalize(
      root ?? _findProjectRoot(Directory.current.path) ?? Directory.current.path,
    );
    final config = projectScanner.readConfig(projectRoot);

    final effectiveLibDir = p.normalize(
      libDir ??
          (config?.libDir != null
              ? p.join(projectRoot, config!.libDir!)
              : p.join(projectRoot, 'lib')),
    );

    // The scan answers what the project configures (its `@KaiselInit` entry
    // point) as well as what it declares (its modules).
    final scan = _scan ??= libraryScanner.scan(Directory(effectiveLibDir));

    final outputPath = p.normalize(
      output ??
          (config?.output != null
              ? p.join(projectRoot, config!.output!)
              : scan.init?.output != null
              ? p.join(projectRoot, scan.init!.output!)
              : p.join(projectRoot, 'lib', 'app', 'app_modules.g.dart')),
    );

    return ProjectContext(
      root: projectRoot,
      libDir: effectiveLibDir,
      outputPath: outputPath,
      packageName:
          projectScanner.readPackageName(projectRoot) ?? p.basename(projectRoot),
      write: write,
      config: config,
    );
  }
}

String? _findProjectRoot(String start) {
  var current = p.normalize(p.absolute(start));
  while (true) {
    if (File(p.join(current, 'pubspec.yaml')).existsSync()) {
      return current;
    }
    final parent = p.dirname(current);
    if (parent == current) {
      return null;
    }
    current = parent;
  }
}
