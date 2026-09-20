import '../model/micro_package.dart';
import '../model/module_info.dart';

/// Writes the sealed route hierarchy, the page builder, the URL mounts and the
/// router config an app runs on.
abstract interface class RegistryEmitter {
  /// Writes the registry for a project whose modules are [modules] and whose
  /// composed micro-packages are [microPackages].
  String write({
    required List<ModuleInfo> modules,
    required String routeClass,
    required String? initialRouteOverride,
    required List<MicroPackageInfo> microPackages,
    required String packageName,
    required String libDir,
  });
}
