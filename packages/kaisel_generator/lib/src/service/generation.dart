/// Generating a project: one run resolves it, scans it once, and writes what it
/// needs — the host's registry plus the manifests it composes, or a
/// micro-package's own manifest.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

import '../helper/naming.dart';
import '../models/config.dart';
import '../models/generation.dart';
import '../models/scan.dart';
import 'annotation_parser.dart';
import 'emitters.dart';
import 'library_scanner.dart';
import 'manifest_parser.dart';
import 'project_scanner.dart';
import 'registry_emitter.dart';

/// The generator: resolve a project, scan it once, deliver the files it needs.
///
/// This runs on the Dart VM, so the same code generates the registry for
/// `dart run kaisel_generator`, for a `build_runner` build, and for the
/// generator's own tests.
class KaiselGenerator {
  const KaiselGenerator();

  /// Generates the output of the project at [root] — the host's `AppRoute`
  /// hierarchy and everything composed into it, or a micro-package's manifest
  /// when the project declares one.
  ///
  /// [root] defaults to the project containing the working directory. [libDir]
  /// and [output] override `kaisel.yaml`, which overrides `@KaiselInit`, which
  /// overrides the conventions (`lib/`, `lib/app/app_modules.g.dart`).
  ///
  /// Set [write] to `false` to get the output's source back in
  /// [KaiselGenerationResult.code] instead of having it written — what a caller
  /// that owns generated files (the `build_runner` builder) wants. Side files are
  /// written either way: a registered package's manifest belongs to another
  /// package, and the registry cannot compile without it.
  ///
  /// [force] rewrites every generated file, including one whose contents did not
  /// change.
  Future<KaiselGenerationResult> generate({
    String? root,
    String? libDir,
    String? output,
    bool force = false,
    bool write = true,
  }) async {
    final stopwatch = Stopwatch()..start();
    final run = GenerationRun(
      root: root,
      libDir: libDir,
      output: output,
      write: write,
    );

    try {
      final generated = run.generate();

      // Side files first: a registered package's manifest belongs to another
      // package, and the registry cannot compile until it exists.
      for (final file in generated.sideFiles) {
        _writeIfChanged(File(file.path), file.source, force: force);
      }
      if (write) {
        _writeIfChanged(
          File(generated.output.path),
          generated.output.source,
          force: force,
        );
      }

      return KaiselGenerationResult(
        success: true,
        filesScanned: run.filesScanned,
        filesParsed: run.filesParsed,
        modulesCount: run.moduleCount,
        elapsedUs: stopwatch.elapsedMicroseconds,
        outputPath: generated.output.path,
        code: write ? null : generated.output.source,
      );
    } on KaiselGenerationException catch (error) {
      // The run reports what it managed to read before it gave up.
      return KaiselGenerationResult(
        success: false,
        error: error.message,
        filesScanned: run.filesScanned,
        filesParsed: run.filesParsed,
        modulesCount: run.moduleCount,
        elapsedUs: stopwatch.elapsedMicroseconds,
      );
    }
  }
}

/// One generation run: the resolved project, the scan of its sources, the request
/// built from both, and the stages that produce the output.
///
/// Each stage is created on first use and reused for the rest of the run, so one
/// run parses its sources once and writes every file it needs from that one scan.
/// Which of the two generations runs is [GenerationRequest.isHost]: a host
/// application gets the registry it runs on, a package that declares
/// `@KaiselMicroPackage` gets its own manifest.
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

  /// `0` until the run reads that far, so a failed run still reports what it read.
  int get filesScanned => _scan?.filesScanned ?? 0;
  int get filesParsed => _scan?.filesParsed ?? 0;
  int get moduleCount => _request?.modules.length ?? 0;

  /// Produces the files for [request].
  ///
  /// Throws a [KaiselGenerationException] when the project cannot be served; the
  /// generator turns that into a failed [KaiselGenerationResult].
  GeneratedOutput generate() =>
      request.isHost ? _hostRegistry() : _microPackageManifest();

  /// A host application: the module registry an app runs on, plus the manifests
  /// of the registered packages that live inside the project.
  ///
  /// A registered package that sits inside this project is generated here —
  /// registering it is the only step the app author writes. A package outside the
  /// project must generate (or ship) its own manifest, because its sources are
  /// not this project's to write.
  GeneratedOutput _hostRegistry() {
    final resolved = _resolveMicroPackages();

    // Package mounts that would land on a name the host already uses get the
    // owner inserted, so composing a package never needs a hand-picked name.
    final microPackages = qualifyMarkers(resolved.packages, request.modules);
    validateMountNames(request.modules);

    final registry = registryEmitter.write(
      modules: request.modules,
      routeClass:
          request.config?.routeClass ?? request.init?.routeClass ?? 'AppRoute',
      initialRouteOverride:
          request.config?.initialRoute ?? request.init?.initialRoute,
      microPackages: microPackages,
      packageName: request.packageName,
      libDir: request.libDir,
    );

    return GeneratedOutput(
      output: GeneratedFile(path: request.outputPath, source: registry),
      sideFiles: resolved.manifests,
    );
  }

  /// A micro-package: one manifest declaring what the package contributes, for
  /// the host applications that compose it.
  GeneratedOutput _microPackageManifest() {
    final scan = libraryScanner.scan(Directory(request.libDir));
    final primary =
        scan.microPackages.isEmpty ? null : scan.microPackages.first;
    final manifestPath = primary?.output != null
        ? p.normalize(p.join(request.root, primary!.output!))
        : p.join(request.libDir, '${request.packageName}.kaisel.dart');

    return GeneratedOutput(
      output: GeneratedFile(
        path: manifestPath,
        source: manifestEmitter.write(
          moduleName: primary?.moduleName ?? toPascalCase(request.packageName),
          modules: request.modules,
          packageName: request.packageName,
          libDir: request.libDir,
          basePrefix: primary?.prefix,
        ),
      ),
    );
  }

  /// Resolves every registered micro-package, generating the manifests of those
  /// that live inside the project.
  ({List<MicroPackageInfo> packages, List<GeneratedFile> manifests})
      _resolveMicroPackages() {
    final packages = <MicroPackageInfo>[];
    final manifests = <GeneratedFile>[];

    for (final reference in request.init?.externalMicroPackages ?? const []) {
      if (packages.any((existing) => existing.className == reference.module)) {
        continue;
      }

      final importUri = reference.importUri;
      if (importUri == null) {
        throw KaiselGenerationException(
          'Cannot infer the import URI for `ExternalMicroPackage(${reference.module})`. '
          "Pass `import: 'package:<package>/<file>.kaisel.dart'` explicitly.",
        );
      }

      final manifestPath = projectScanner.resolveImportUri(
        root: request.root,
        outputDir: p.dirname(request.outputPath),
        importUri: importUri,
      );

      final packageLibDir = _packageLibDirWithinProject(importUri);
      final manifest = packageLibDir == null
          ? _readManifest(reference.module, manifestPath)
          : _generatedManifest(
              reference.module,
              manifestPath: manifestPath,
              packageLibDir: packageLibDir,
              manifests: manifests,
            );

      packages.add(
        MicroPackageInfo(
          className: reference.module,
          importUri: importUri,
          mounts: manifest.mounts,
        ),
      );
    }

    return (packages: packages, manifests: manifests);
  }

  /// Generates an in-project package's manifest and records the file to write.
  MicroPackageManifest _generatedManifest(
    String moduleClass, {
    required String manifestPath,
    required String packageLibDir,
    required List<GeneratedFile> manifests,
  }) {
    final packageRoot = p.dirname(packageLibDir);
    final scan = libraryScanner.scan(Directory(packageLibDir));
    if (scan.modules.isEmpty) {
      throw KaiselGenerationException(
        '`$packageRoot` is registered as a micro-package but declares no '
        '`@KaiselModule` in `$packageLibDir`.',
      );
    }

    final primary =
        scan.microPackages.isEmpty ? null : scan.microPackages.first;
    final packageName =
        projectScanner.readPackageName(packageRoot) ?? p.basename(packageRoot);

    final source = manifestEmitter.write(
      moduleName: primary?.moduleName ?? toPascalCase(packageName),
      modules: sortModules(scan.modules),
      packageName: packageName,
      libDir: packageLibDir,
      basePrefix: primary?.prefix,
    );
    manifests.add(GeneratedFile(path: manifestPath, source: source));

    // The host composes what the manifest declares, not what the package's
    // modules imply: read the generated contract back exactly as a host does for
    // a manifest it did not write.
    return _parseManifest(moduleClass, manifestPath, source);
  }

  /// Reads a registered package's manifest from disk, or reports what to do.
  MicroPackageManifest _readManifest(String moduleClass, String manifestPath) {
    final file = File(manifestPath);
    if (!file.existsSync()) {
      throw KaiselGenerationException(
        'Micro-package `$moduleClass` could not be read at `$manifestPath`. '
        'Generate it first (`dart run kaisel_generator` in that package) and run '
        '`dart pub get` in the host app.',
      );
    }

    final String source;
    try {
      source = file.readAsStringSync();
    } on FileSystemException catch (error) {
      throw KaiselGenerationException(
        'Micro-package `$moduleClass` could not be read at `$manifestPath`: '
        '${error.message}',
      );
    }

    return _parseManifest(moduleClass, manifestPath, source);
  }

  MicroPackageManifest _parseManifest(
    String moduleClass,
    String manifestPath,
    String source,
  ) {
    final manifest = manifestParser.parse(source);
    if (manifest == null) {
      throw KaiselGenerationException(
        '`$manifestPath` is not a micro-package manifest written by a compatible '
        'kaisel_generator (no `KaiselModule` registry). Regenerate it.',
      );
    }
    if (manifest.className != moduleClass) {
      throw KaiselGenerationException(
        '`$manifestPath` declares the registry `${manifest.className}`, but the host '
        'registers `$moduleClass`. Register the class the package generates.',
      );
    }
    return manifest;
  }

  /// The `lib/` of the package an import URI belongs to, when that package lives
  /// inside this project.
  String? _packageLibDirWithinProject(String importUri) {
    if (!importUri.startsWith('package:')) {
      return null;
    }

    final rest = importUri.substring('package:'.length);
    final separator = rest.indexOf('/');
    if (separator <= 0) {
      return null;
    }

    final libDir = projectScanner.resolvePackageLibDir(
      root: request.root,
      package: rest.substring(0, separator),
    );
    final inside =
        p.isWithin(request.root, libDir) || p.equals(request.root, libDir);
    return inside ? libDir : null;
  }

  ProjectContext _resolveProject() {
    final projectRoot = p.normalize(
      root ??
          _findProjectRoot(Directory.current.path) ??
          Directory.current.path,
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
      packageName: projectScanner.readPackageName(projectRoot) ??
          p.basename(projectRoot),
      write: write,
      config: config,
    );
  }
}

/// Writes [content] to [file] unless it is already exactly there, so a run that
/// changes nothing does not touch the file.
void _writeIfChanged(File file, String content, {required bool force}) {
  if (!force && file.existsSync() && file.readAsStringSync() == content) {
    return;
  }

  try {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  } on FileSystemException catch (error) {
    throw KaiselGenerationException(
      'Could not write `${file.path}`: ${error.message}',
    );
  }
}

/// The nearest directory at or above [start] that holds a `pubspec.yaml`.
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
