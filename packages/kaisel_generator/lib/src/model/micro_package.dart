/// The micro-package contract.
///
/// A micro-package generates its own `<package>.kaisel.dart` manifest, which
/// declares one typed mount per module it contributes. A host application
/// composes that manifest without scanning the package for routes of its own:
/// it binds each declaration to one of its own marker routes, so a mount is never
/// resolved by name.
library;

import 'module_info.dart';
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

/// Gives every mount a package contributes a host marker name that cannot collide
/// with a name the host already uses: `<Feature>Mount` becomes
/// `<Feature><Owner>Mount`, so the package `profile` declaring `ShopMount` next
/// to the host's own `ShopMount` is bound to `ShopProfileMount`.
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
