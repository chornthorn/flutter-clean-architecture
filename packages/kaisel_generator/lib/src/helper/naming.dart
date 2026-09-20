/// The names and orderings the generator derives from what a project declares.
///
/// Pure functions over the models: a `@KaiselModule` class name carries three
/// derived names and each has exactly one spelling rule, and a host's mounts are
/// one namespace that a micro-package's mounts have to be qualified against.
library;

import '../models/generation.dart';
import '../models/scan.dart';

/// `FeatureShop` → `feature_shop`.
String toSnakeCase(String value) {
  final buffer = StringBuffer();
  var previousWasUnderscore = false;

  for (var index = 0; index < value.length; index++) {
    final char = value[index];
    if (char != char.toLowerCase()) {
      if (index > 0 && !previousWasUnderscore) {
        buffer.write('_');
      }
      buffer.write(char.toLowerCase());
      previousWasUnderscore = false;
    } else {
      buffer.write(char);
      previousWasUnderscore = char == '_';
    }
  }

  return buffer.toString();
}

/// `feature_shop` → `FeatureShop`.
String toPascalCase(String value) {
  final buffer = StringBuffer();
  var capitalizeNext = true;

  for (var index = 0; index < value.length; index++) {
    final char = value[index];
    if (char == '_' || char == '-' || char == ' ') {
      capitalizeNext = true;
      continue;
    }
    if (capitalizeNext) {
      buffer.write(char.toUpperCase());
      capitalizeNext = false;
    } else {
      buffer.write(char);
    }
  }

  return buffer.toString();
}

/// `ShopMount` → `shopMount`, the field a micro-package manifest declares.
String toCamelCase(String value) {
  if (value.isEmpty) {
    return '';
  }
  return value[0].toLowerCase() + value.substring(1);
}

/// `ShopRouterModule` → `Shop`, the stem of a module's default names.
String moduleBaseName(String className) {
  final withoutSuffix = className.endsWith('RouterModule')
      ? className.substring(0, className.length - 'RouterModule'.length)
      : className;
  return withoutSuffix.endsWith('Module')
      ? withoutSuffix.substring(0, withoutSuffix.length - 'Module'.length)
      : withoutSuffix;
}

/// Initial landing module first, then by mount name, so generated output does not
/// depend on the order the filesystem handed the files over.
List<ModuleInfo> sortModules(List<ModuleInfo> modules) {
  final sorted = [...modules];
  sorted.sort((a, b) {
    if (a.isInitial != b.isInitial) {
      return a.isInitial ? -1 : 1;
    }
    return a.mountName.compareTo(b.mountName);
  });
  return sorted;
}

/// Guard rail: a host's own mounts are one namespace, so two modules claiming
/// the same name would silently lose a route.
///
/// A micro-package cannot cause this — the marker names it contributes are
/// qualified against whatever the host already declares (see [qualifyMarkers]).
void validateMountNames(List<ModuleInfo> modules) {
  final seen = <String>{};
  for (final module in modules) {
    if (!seen.add(module.mountName)) {
      throw KaiselGenerationException(
        'Mount name `${module.mountName}` is declared twice by the host app. '
        'Give one module a distinct `mount:` name.',
      );
    }
  }
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
