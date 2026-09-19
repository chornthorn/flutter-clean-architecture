import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:spi/spi.dart';

import '../model/naming.dart';
import '../spi/emitter.dart';
import '../spi/generation.dart';
import '../spi/scanner.dart';

/// Serves a micro-package: one manifest declaring what the package contributes,
/// for the host applications that compose it.
///
/// A package with no `@KaiselInit` and no `kaisel.yaml` is a micro-package — it
/// generates its own manifest and no host registry.
class MicroPackageProvider implements GenerationProvider {
  const MicroPackageProvider(this.session);

  /// The session this provider was created for; everything it needs — the
  /// scanner and the emitter — comes from there.
  final ProviderSession session;

  @override
  void close() {}

  @override
  bool supports(GenerationRequest request) => !request.isHost;

  @override
  GeneratedOutput generate(GenerationRequest request) {
    final scan = session.provider(LibraryScannerSpi.instance).scan(
      Directory(request.libDir),
    );
    final primary = scan.microPackages.isEmpty ? null : scan.microPackages.first;
    final manifestPath = primary?.output != null
        ? p.normalize(p.join(request.root, primary!.output!))
        : p.join(request.libDir, '${request.packageName}.kaisel.dart');

    return GeneratedOutput(
      output: GeneratedFile(
        path: manifestPath,
        source: session.provider(ManifestEmitterSpi.instance).write(
              moduleName: primary?.moduleName ?? toPascalCase(request.packageName),
              modules: request.modules,
              packageName: request.packageName,
              libDir: request.libDir,
              basePrefix: primary?.prefix,
            ),
      ),
    );
  }
}

/// Creates the built-in [MicroPackageProvider].
class MicroPackageProviderFactory implements GenerationProviderFactory {
  const MicroPackageProviderFactory();

  @override
  String get id => 'micro-package';

  @override
  int get order => defaultProviderOrder;

  @override
  ProviderScope get scope => ProviderScope.session;

  @override
  GenerationProvider create(ProviderSession session) => MicroPackageProvider(session);
}
