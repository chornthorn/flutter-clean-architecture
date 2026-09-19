import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:spi/spi.dart';

import '../model/generation_result.dart';
import '../model/library_scan.dart';
import '../model/module_info.dart';
import '../model/project_context.dart';
import 'generation.dart';
import 'scanner.dart';

/// One generation run (Keycloak: `KeycloakSession`).
///
/// A session owns the run: the resolved project, the scan of its sources and the
/// request built from both. It also owns the providers created for it, which the
/// framework's [DefaultProviderSession] creates on first use, caches, and closes —
/// nothing outside this class constructs a provider.
///
/// A Kaisel provider is handed the framework's [ProviderSession] type, so it can
/// ask for other providers but sees neither the project nor the scan — a
/// generation provider is given the [GenerationRequest] it serves instead.
class KaiselSession extends DefaultProviderSession {
  KaiselSession({
    required super.providerManager,
    this.root,
    this.libDir,
    this.output,
    this.write = true,
  });

  /// Project root the run was asked for, or `null` to find the nearest one.
  final String? root;

  /// Directory to scan, or `null` to take `kaisel.yaml`'s or `lib/`.
  final String? libDir;

  /// Path of the output file, or `null` to take the configured or conventional
  /// one.
  final String? output;

  /// Whether the caller wants the output written, or its source handed back.
  final bool write;

  ProjectContext? _project;
  LibraryScan? _scan;
  GenerationRequest? _request;

  /// The project this session runs against, with its configuration resolved.
  ProjectContext get project => _project ??= _resolveProject();

  /// What the scan of the project's sources found.
  LibraryScan get scan {
    project; // Resolving the project resolves the scan with it.
    return _scan!;
  }

  /// What the providers are asked to generate.
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

  /// The provider of [spi] with [id], or the first one when [id] is `null`.
  ///
  /// The framework reports a look-up it cannot serve generically; a generation run
  /// reports it with the ids the bootstrap registered, because a missing provider
  /// there is a wiring mistake the user has to fix.
  @override
  T provider<T extends Provider>(Spi<T> spi, [String? id]) {
    try {
      return super.provider(spi, id);
    } on ProviderException {
      final registered =
          providerManager.factoriesFor(spi).map((factory) => factory.id).join(', ');
      throw KaiselGenerationException(
        'No Kaisel provider of `${spi.name}` is registered'
        '${id == null ? '' : ' under id `$id`'}.'
        '${registered.isEmpty ? '' : ' Registered ids: $registered.'}',
      );
    }
  }

  ProjectContext _resolveProject() {
    final scanner = provider(ProjectScannerSpi.instance);
    final projectRoot = p.normalize(
      root ?? _findProjectRoot(Directory.current.path) ?? Directory.current.path,
    );
    final config = scanner.readConfig(projectRoot);

    final effectiveLibDir = p.normalize(
      libDir ??
          (config?.libDir != null
              ? p.join(projectRoot, config!.libDir!)
              : p.join(projectRoot, 'lib')),
    );

    // The scan answers what the project configures (its `@KaiselInit` entry
    // point) as well as what it declares (its modules).
    final scan = _scan ??= provider(LibraryScannerSpi.instance).scan(
      Directory(effectiveLibDir),
    );

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
      packageName: scanner.readPackageName(projectRoot) ?? p.basename(projectRoot),
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
