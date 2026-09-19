import 'dart:io';

import 'package:path/path.dart' as p;

import '../emitter/manifest_emitter.dart';
import '../emitter/registry_emitter.dart';
import '../model/generation_result.dart';
import '../model/init_info.dart';
import '../model/micro_package.dart';
import '../model/module_info.dart';
import '../model/naming.dart';
import '../parser/manifest_parser.dart';
import '../scanner/library_scanner.dart';
import '../scanner/project_scanner.dart';

/// Coordinates the scan, the composition and the emitters into one registry —
/// or, for a package that is itself a micro-package, one manifest.
///
/// This runs on the Dart VM, so the same code generates the registry for
/// `dart run kaisel_generator`, for a `build_runner` build, and for the
/// generator's own tests.
class KaiselGenerator {
  const KaiselGenerator({
    this.libraryScanner = const LibraryScanner(),
    this.projectScanner = const ProjectScanner(),
    this.manifestParser = const ManifestParser(),
    this.registryEmitter = const RegistryEmitter(),
    this.manifestEmitter = const ManifestEmitter(),
  });

  final LibraryScanner libraryScanner;
  final ProjectScanner projectScanner;
  final ManifestParser manifestParser;
  final RegistryEmitter registryEmitter;
  final ManifestEmitter manifestEmitter;

  /// Generates the module registry of the project at [root] — the host's
  /// `AppRoute` hierarchy and everything composed into it, or a micro-package's
  /// manifest when the project declares one.
  ///
  /// [root] defaults to the project containing the working directory. [libDir]
  /// and [output] override `kaisel.yaml`, which overrides `@KaiselInit`, which
  /// overrides the conventions (`lib/`, `lib/app/app_modules.g.dart`).
  ///
  /// Set [write] to `false` to get the registry source back in
  /// [KaiselGenerationResult.code] instead of having it written — what a caller
  /// that owns generated files (the `build_runner` builder) wants. Micro-package
  /// manifests are written either way: they belong to other packages, and the
  /// registry cannot compile until they exist.
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
    final started = DateTime.now();
    var scanned = 0;
    var parsed = 0;
    var modulesCount = 0;

    KaiselGenerationResult failure(String message) => KaiselGenerationResult(
          success: false,
          error: message,
          filesScanned: scanned,
          filesParsed: parsed,
          modulesCount: modulesCount,
          elapsedUs: _elapsedUs(started),
        );

    try {
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

      final init = libraryScanner.findInit(Directory(effectiveLibDir));
      final isHostApp = init != null || config != null;

      final outputPath = p.normalize(
        output ??
            (config?.output != null
                ? p.join(projectRoot, config!.output!)
                : init?.output != null
                    ? p.join(projectRoot, init!.output!)
                    : p.join(projectRoot, 'lib', 'app', 'app_modules.g.dart')),
      );

      final scan = libraryScanner.scanModules(Directory(effectiveLibDir));
      scanned = scan.filesScanned;
      parsed = scan.filesParsed;
      final modules = sortModules(scan.modules);
      modulesCount = modules.length;

      // No `@KaiselInit` and no `kaisel.yaml`: this package *is* a micro-package,
      // so it generates its manifest and no host registry.
      if (!isHostApp) {
        return _writeMicroPackageManifest(
          projectRoot: projectRoot,
          libDir: effectiveLibDir,
          modules: modules,
          force: force,
          started: started,
          filesScanned: scanned,
          filesParsed: parsed,
        );
      }

      final microPackages = _resolveMicroPackages(
        root: projectRoot,
        outputDir: p.dirname(outputPath),
        references: init?.externalMicroPackages ?? const [],
        force: force,
      );

      // Package mounts that would land on a name the host already uses get the
      // owner inserted, so composing a package never needs a hand-picked name.
      final qualified = qualifyMarkers(microPackages, modules);
      validateMountNames(modules);

      final registry = registryEmitter.write(
        modules: modules,
        routeClass: config?.routeClass ?? init?.routeClass ?? 'AppRoute',
        initialRouteOverride: config?.initialRoute ?? init?.initialRoute,
        microPackages: qualified,
        packageName: projectScanner.readPackageName(projectRoot) ?? p.basename(projectRoot),
        libDir: effectiveLibDir,
      );

      if (write) {
        _writeIfChanged(File(outputPath), registry, force: force);
      }

      return KaiselGenerationResult(
        success: true,
        filesScanned: scanned,
        filesParsed: parsed,
        modulesCount: modulesCount,
        elapsedUs: _elapsedUs(started),
        outputPath: outputPath,
        code: write ? null : registry,
      );
    } on KaiselGenerationException catch (error) {
      return failure(error.message);
    }
  }

  /// Resolves every registered micro-package to its generated manifest.
  ///
  /// A registered package that lives inside this project is generated here —
  /// registering it is the only step the app author writes. A package outside the
  /// project must generate (or ship) its own manifest, because its sources are not
  /// this project's to write.
  List<MicroPackageInfo> _resolveMicroPackages({
    required String root,
    required String outputDir,
    required List<ExternalMicroPackageReference> references,
    required bool force,
  }) {
    final resolved = <MicroPackageInfo>[];

    for (final reference in references) {
      if (resolved.any((existing) => existing.className == reference.module)) {
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
        root: root,
        outputDir: outputDir,
        importUri: importUri,
      );

      final packageLibDir = _packageLibDirWithinProject(root, importUri);
      if (packageLibDir != null) {
        _writeRegisteredManifest(
          packageLibDir: packageLibDir,
          manifestPath: manifestPath,
          force: force,
        );
      }

      final manifest = _loadManifest(reference.module, manifestPath);
      if (manifest.className != reference.module) {
        throw KaiselGenerationException(
          '`$manifestPath` declares the registry `${manifest.className}`, but the host '
          'registers `${reference.module}`. Register the class the package generates.',
        );
      }

      resolved.add(
        MicroPackageInfo(
          className: reference.module,
          importUri: importUri,
          mounts: manifest.mounts,
        ),
      );
    }

    return resolved;
  }

  /// Reads a registered package's manifest, or reports what to do about it.
  MicroPackageManifest _loadManifest(String moduleClass, String manifestPath) {
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

    final manifest = manifestParser.parse(source);
    if (manifest == null) {
      throw KaiselGenerationException(
        '`$manifestPath` is not a micro-package manifest written by a compatible '
        'kaisel_generator (no `KaiselModule` registry). Regenerate it.',
      );
    }
    return manifest;
  }

  /// Generates a registered in-project package's manifest, so that registering it
  /// is the only step the app writes.
  void _writeRegisteredManifest({
    required String packageLibDir,
    required String manifestPath,
    required bool force,
  }) {
    final packageRoot = p.dirname(packageLibDir);
    final scan = libraryScanner.scanModules(Directory(packageLibDir));
    if (scan.modules.isEmpty) {
      throw KaiselGenerationException(
        '`$packageRoot` is registered as a micro-package but declares no '
        '`@KaiselModule` in `$packageLibDir`.',
      );
    }

    final declared = _declaredMicroPackage(packageLibDir);
    final packageName = projectScanner.readPackageName(packageRoot) ?? p.basename(packageRoot);

    _writeIfChanged(
      File(manifestPath),
      manifestEmitter.write(
        moduleName: declared?.moduleName ?? toPascalCase(packageName),
        modules: sortModules(scan.modules),
        packageName: packageName,
        libDir: packageLibDir,
        basePrefix: declared?.prefix,
      ),
      force: force,
    );
  }

  /// Generates the manifest of a package that is itself a micro-package.
  KaiselGenerationResult _writeMicroPackageManifest({
    required String projectRoot,
    required String libDir,
    required List<ModuleInfo> modules,
    required bool force,
    required DateTime started,
    required int filesScanned,
    required int filesParsed,
  }) {
    final packageName =
        projectScanner.readPackageName(projectRoot) ?? p.basename(projectRoot);
    final declared = _declaredMicroPackage(libDir);
    final manifestPath = declared?.output != null
        ? p.normalize(p.join(projectRoot, declared!.output!))
        : p.join(libDir, '$packageName.kaisel.dart');

    _writeIfChanged(
      File(manifestPath),
      manifestEmitter.write(
        moduleName: declared?.moduleName ?? toPascalCase(packageName),
        modules: modules,
        packageName: packageName,
        libDir: libDir,
        basePrefix: declared?.prefix,
      ),
      force: force,
    );

    return KaiselGenerationResult(
      success: true,
      filesScanned: filesScanned,
      filesParsed: filesParsed,
      modulesCount: modules.length,
      elapsedUs: _elapsedUs(started),
      outputPath: manifestPath,
    );
  }

  /// The `lib/` of the package an import URI belongs to, when that package lives
  /// inside [root].
  String? _packageLibDirWithinProject(String root, String importUri) {
    if (!importUri.startsWith('package:')) {
      return null;
    }

    final rest = importUri.substring('package:'.length);
    final separator = rest.indexOf('/');
    if (separator <= 0) {
      return null;
    }

    final libDir = projectScanner.resolvePackageLibDir(
      root: root,
      package: rest.substring(0, separator),
    );
    final inside = p.isWithin(root, libDir) || p.equals(root, libDir);
    return inside ? libDir : null;
  }

  /// The first `@KaiselMicroPackage` declaration under [libDir], if any.
  MicroPackageDeclaration? _declaredMicroPackage(String libDir) {
    final declared = libraryScanner.findMicroPackages(Directory(libDir));
    return declared.isEmpty ? null : declared.first;
  }
}

/// Initial landing module first, then by mount name, so generated output does not
/// depend on the order the filesystem handed the files over.
List<ModuleInfo> sortModules(List<ModuleInfo> modules) {
  final sorted = [...modules];
  sorted.sort((a, b) {
    if (a.isInitial != b.isInitial) {
      return a.isInitial ? -1 : 1;
    }
    return a.mountName.compareTo(b.mountName);
  });
  return sorted;
}

/// Guard rail: the host's own mounts are one namespace, so two modules claiming
/// the same name would silently lose a route. A micro-package cannot cause this
/// — its markers are qualified against whatever the host already declares.
void validateMountNames(List<ModuleInfo> modules) {
  final seen = <String>{};
  for (final module in modules) {
    if (!seen.add(module.mountName)) {
      throw KaiselGenerationException(
        'Mount name `${module.mountName}` is declared twice by the host app. '
        'Give one module a distinct `mount:` name.',
      );
    }
  }
}

/// Gives every package-owned mount a host marker name that cannot collide with a
/// name the host already uses: `<Feature>Mount` becomes `<Feature><Owner>Mount`,
/// so the package `profile` declaring `ShopMount` next to the host's own
/// `ShopMount` is bound to `ShopProfileMount`.
///
/// A name that is still free is left exactly as the package declared it, so
/// registering a package never renames a marker the host already has.
List<MicroPackageInfo> qualifyMarkers(
  List<MicroPackageInfo> packages,
  List<ModuleInfo> modules,
) {
  // The host's own mounts hold their names; a package that wants one of them is
  // the one that moves.
  final taken = {for (final module in modules) module.mountName};

  final qualified = <MicroPackageInfo>[];
  for (final package in packages) {
    final mounts = [
      for (final mount in package.mounts)
        mount.withHostMarker(_claim(mount.mountName, package.owner, taken)),
    ];
    qualified.add(package.withMounts(mounts));
  }
  return qualified;
}

String _claim(String preferred, String owner, Set<String> taken) {
  var marker = preferred;
  while (taken.contains(marker)) {
    marker = _insertOwner(marker, owner);
  }
  taken.add(marker);
  return marker;
}

/// `ShopMount` + `Profile` → `ShopProfileMount`.
String _insertOwner(String marker, String owner) => marker.endsWith('Mount')
    ? '${marker.substring(0, marker.length - 'Mount'.length)}${owner}Mount'
    : '$marker$owner';

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

int _elapsedUs(DateTime started) => DateTime.now().difference(started).inMicroseconds;
