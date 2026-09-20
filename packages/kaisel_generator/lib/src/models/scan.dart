/// What a scan of a package's `lib/` finds: its modules, its entry point, and the
/// micro-package contract.
///
/// Plain values read from source, so they can be asserted on without a build: the
/// scan needs an AST, never a resolved program.
library;

import '../helper/naming.dart';
import 'config.dart';

/// One `@KaiselModule` class, with the names its registry entry needs.
class ModuleInfo {
  const ModuleInfo({
    required this.className,
    required this.routeType,
    required this.mountName,
    required this.codecName,
    required this.filePath,
    this.prefix,
    this.isInitial = false,
  });

  /// The module class, e.g. `ShopRouterModule`.
  final String className;

  /// The module's route family, e.g. `ShopRoute`.
  final String routeType;

  /// The host marker route generated for this module, e.g. `ShopMount`.
  final String mountName;

  /// The module's codec, e.g. `ShopRouteCodec`. Never null: a module without an
  /// explicit `codec:` or `codec` getter falls back to `<routeType>Codec`.
  final String codecName;

  /// Absolute path of the file that declares the module.
  final String filePath;

  /// URL prefix the module owns, or `null` when it is not URL-routed.
  final String? prefix;

  /// Whether the host should land on this mount by default.
  final bool isInitial;

  /// Whether this module owns a URL prefix, and so belongs in `appModuleMounts`.
  bool get isRouted => prefix != null;
}

/// Everything Kaisel annotations declare under a package's `lib/`.
class LibraryScan {
  const LibraryScan({
    required this.modules,
    required this.microPackages,
    required this.filesScanned,
    required this.filesParsed,
    this.init,
  });

  /// Every `@KaiselModule` class, in file order.
  final List<ModuleInfo> modules;

  /// The `@KaiselInit` entry point, when the package declares one.
  final InitInfo? init;

  /// Every `@KaiselMicroPackage` declaration, in file order. A package generates
  /// one manifest, from the first one.
  final List<MicroPackageDeclaration> microPackages;

  /// `.dart` files the walk considered.
  final int filesScanned;

  /// Files that named a Kaisel annotation and were therefore parsed.
  final int filesParsed;
}

/// A `@KaiselMicroPackage` declaration: the package generates one manifest from
/// the first one it finds.
class MicroPackageDeclaration {
  const MicroPackageDeclaration({
    required this.moduleName,
    required this.filePath,
    this.output,
    this.prefix,
  });

  /// The registry's base name, e.g. `Profile` for `ProfileKaiselModule`.
  final String moduleName;

  /// Absolute path of the file that declares the annotation.
  final String filePath;

  /// `output:` — a non-conventional manifest path, relative to the package root.
  final String? output;

  /// `prefix:` — a base URL prefix prepended to every mount in the manifest.
  final String? prefix;
}

/// What a generated manifest declares: its registry class and its mounts.
class MicroPackageManifest {
  const MicroPackageManifest({required this.className, required this.mounts});

  /// Generated registry class, e.g. `FeatureShopKaiselModule`.
  final String className;

  /// Mount declarations, in declaration order.
  final List<MicroPackageMountInfo> mounts;
}

/// One mount a micro-package declares through `KaiselMicroMount`.
class MicroPackageMountInfo {
  const MicroPackageMountInfo({
    required this.fieldName,
    required this.isRouted,
    required this.isInitial,
    this.hostMarker = '',
  });

  /// Field name of the declaration, e.g. `shopMount`.
  final String fieldName;

  /// Whether the declaration owns a URL prefix.
  final bool isRouted;

  /// Whether the host should land on this mount by default.
  final bool isInitial;

  /// Host marker class this mount is bound to, once the host qualified it against
  /// names it already uses. Empty until then.
  final String hostMarker;

  /// Host marker class this mount asks for, e.g. `ShopMount`.
  String get mountName => toPascalCase(fieldName);

  /// The host-side marker name, qualified when the preferred name was taken: the
  /// package's `ShopMount` becomes `ShopProfileMount` next to the host's own
  /// `ShopMount`.
  String get marker => hostMarker.isEmpty ? mountName : hostMarker;

  MicroPackageMountInfo withHostMarker(String marker) => MicroPackageMountInfo(
        fieldName: fieldName,
        isRouted: isRouted,
        isInitial: isInitial,
        hostMarker: marker,
      );
}

/// A micro-package a host composes: its manifest, resolved to the import URI the
/// host's registry imports it by.
class MicroPackageInfo {
  const MicroPackageInfo({
    required this.className,
    required this.importUri,
    required this.mounts,
  });

  /// Generated registry class, e.g. `FeatureShopKaiselModule`.
  final String className;

  /// Import URI the host's generated file uses for the manifest.
  final String importUri;

  /// Mount declarations, in declaration order.
  final List<MicroPackageMountInfo> mounts;

  /// The package's name in a qualified marker: `ShopProfileMount` comes from the
  /// `ShopMount` of the package whose registry is `ProfileKaiselModule`.
  String get owner => className.endsWith('KaiselModule')
      ? className.substring(0, className.length - 'KaiselModule'.length)
      : className;

  /// The mount this package declares as the host's landing route, if any.
  MicroPackageMountInfo? get initialMount {
    for (final mount in mounts) {
      if (mount.isInitial) {
        return mount;
      }
    }
    return null;
  }

  MicroPackageInfo withMounts(List<MicroPackageMountInfo> mounts) =>
      MicroPackageInfo(
        className: className,
        importUri: importUri,
        mounts: mounts,
      );
}
