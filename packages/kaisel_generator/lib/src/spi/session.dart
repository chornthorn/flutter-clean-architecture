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
/// request built from both. It also owns the providers created for it — created
/// on first use through the factories registered with the [providerManager],
/// cached, and closed when the session closes. Nothing outside this class
/// constructs a provider.
///
/// The provider half is the framework's [ProviderSession]; a Kaisel provider is
/// handed this type, so it can ask for other providers but sees neither the
/// project nor the scan — a generation provider is given the [GenerationRequest]
/// it serves instead.
class KaiselSession implements ProviderSession {
  KaiselSession({
    required this.providerManager,
    this.root,
    this.libDir,
    this.output,
    this.write = true,
  });

  final ProviderManager providerManager;

  /// Project root the run was asked for, or `null` to find the nearest one.
  final String? root;

  /// Directory to scan, or `null` to take `kaisel.yaml`'s or `lib/`.
  final String? libDir;

  /// Path of the output file, or `null` to take the configured or conventional
  /// one.
  final String? output;

  /// Whether the caller wants the output written, or its source handed back.
  final bool write;

  final Map<String, Provider> _providers = {};
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
  @override
  T provider<T extends Provider>(Spi<T> spi, [String? id]) {
    final factory = providerManager.factoryFor(spi, id);
    if (factory == null) {
      final registered = providerManager.factoriesFor(spi).map((factory) => factory.id).join(', ');
      throw KaiselGenerationException(
        'No Kaisel provider of `${spi.name}` is registered'
        '${id == null ? '' : ' under id `$id`'}.'
        '${registered.isEmpty ? '' : ' Registered ids: $registered.'}',
      );
    }

    return _providers.putIfAbsent(
      '${spi.name}/${factory.id}',
      () => factory.create(this),
    ) as T;
  }

  /// Every provider of [spi], in the order the SPI asks its factories.
  @override
  List<T> providers<T extends Provider>(Spi<T> spi) => [
        for (final factory in providerManager.factoriesFor(spi)) provider(spi, factory.id),
      ];

  /// Closes every provider this session created.
  @override
  void close() {
    for (final provider in _providers.values) {
      provider.close();
    }
    _providers.clear();
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
