import 'dart:io';

import 'package:path/path.dart' as p;

import '../generation/generation.dart';
import '../model/naming.dart';
import '../session/generation_run.dart';

/// Serves a micro-package: one manifest declaring what the package contributes,
/// for the host applications that compose it.
///
/// A package with no `@KaiselInit` and no `kaisel.yaml` is a micro-package — it
/// generates its own manifest and no host registry.
class MicroPackageGeneration implements Generation {
  const MicroPackageGeneration(this.run);

  /// The run this serves: the resolved project, its scan, and the stages that
  /// read and write it.
  final GenerationRun run;

  @override
  GeneratedOutput generate(GenerationRequest request) {
    final scan = run.libraryScanner.scan(Directory(request.libDir));
    final primary = scan.microPackages.isEmpty ? null : scan.microPackages.first;
    final manifestPath = primary?.output != null
        ? p.normalize(p.join(request.root, primary!.output!))
        : p.join(request.libDir, '${request.packageName}.kaisel.dart');

    return GeneratedOutput(
      output: GeneratedFile(
        path: manifestPath,
        source: run.manifestEmitter.write(
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
