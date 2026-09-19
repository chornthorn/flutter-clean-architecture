/// The micro-package contract.
///
/// A micro-package generates its own `<package>.kaisel.dart` manifest, which
/// declares one typed mount per module it contributes. A host application
/// composes that manifest without scanning the package for routes of its own:
/// it binds each declaration to one of its own marker routes, so a mount is never
/// resolved by name.
library;

import 'naming.dart';

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
