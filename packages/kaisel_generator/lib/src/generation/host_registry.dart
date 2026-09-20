import 'dart:io';

import 'package:path/path.dart' as p;

import '../generation/generation.dart';
import '../model/generation_result.dart';
import '../model/micro_package.dart';
import '../model/module_info.dart';
import '../model/naming.dart';
import '../session/generation_run.dart';

/// Serves a host application: the module registry an app runs on, plus the
/// manifests of the registered packages that live inside the project.
///
/// A registered package that sits inside this project is generated here —
/// registering it is the only step the app author writes. A package outside the
/// project must generate (or ship) its own manifest, because its sources are not
/// this project's to write.
class HostRegistryGeneration implements Generation {
  const HostRegistryGeneration(this.run);

  /// The run this serves: the resolved project, its scan, and the stages that
  /// read and write it.
  final GenerationRun run;

  @override
  GeneratedOutput generate(GenerationRequest request) {
    final resolved = _resolveMicroPackages(request);

    // Package mounts that would land on a name the host already uses get the
    // owner inserted, so composing a package never needs a hand-picked name.
    final microPackages = qualifyMarkers(resolved.packages, request.modules);
    validateMountNames(request.modules);

    final registry = run.registryEmitter.write(
      modules: request.modules,
      routeClass: request.config?.routeClass ?? request.init?.routeClass ?? 'AppRoute',
      initialRouteOverride: request.config?.initialRoute ?? request.init?.initialRoute,
      microPackages: microPackages,
      packageName: request.packageName,
      libDir: request.libDir,
    );

    return GeneratedOutput(
      output: GeneratedFile(path: request.outputPath, source: registry),
      sideFiles: resolved.manifests,
    );
  }

  /// Resolves every registered micro-package, generating the manifests of those
  /// that live inside the project.
  ({List<MicroPackageInfo> packages, List<GeneratedFile> manifests}) _resolveMicroPackages(
    GenerationRequest request,
  ) {
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

      final manifestPath = run.projectScanner.resolveImportUri(
        root: request.root,
        outputDir: p.dirname(request.outputPath),
        importUri: importUri,
      );

      final packageLibDir = _packageLibDirWithinProject(request.root, importUri);
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
    final scan = run.libraryScanner.scan(Directory(packageLibDir));
    if (scan.modules.isEmpty) {
      throw KaiselGenerationException(
        '`$packageRoot` is registered as a micro-package but declares no '
        '`@KaiselModule` in `$packageLibDir`.',
      );
    }

    final primary = scan.microPackages.isEmpty ? null : scan.microPackages.first;
    final packageName =
        run.projectScanner.readPackageName(packageRoot) ?? p.basename(packageRoot);

    final source = run.manifestEmitter.write(
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
    final manifest = run.manifestParser.parse(source);
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

    final libDir = run.projectScanner.resolvePackageLibDir(
      root: root,
      package: rest.substring(0, separator),
    );
    final inside = p.isWithin(root, libDir) || p.equals(root, libDir);
    return inside ? libDir : null;
  }
}
