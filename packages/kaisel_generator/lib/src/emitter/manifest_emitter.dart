import '../model/module_info.dart';

/// Writes one registry class declaring what a micro-package contributes, for a
/// host to bind to its own marker routes.
abstract interface class ManifestEmitter {
  /// Writes the manifest of the package module named [moduleName].
  String write({
    required String moduleName,
    required List<ModuleInfo> modules,
    required String packageName,
    required String libDir,
    required String? basePrefix,
  });
}
