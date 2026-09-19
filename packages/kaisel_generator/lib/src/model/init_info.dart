/// The configuration of a `@KaiselInit` entry point.
library;

import 'naming.dart';

/// The configuration of the `@KaiselInit` entry point.
class InitInfo {
  const InitInfo({
    this.output,
    this.routeClass,
    this.initialRoute,
    this.externalMicroPackages = const [],
  });

  /// `output:` — where the registry is written, relative to the project root.
  final String? output;

  /// `routeClass:` — the host's sealed route class name.
  final String? routeClass;

  /// `initialRoute:` — the mount the host lands on, overriding `isInitial`.
  final String? initialRoute;

  /// Micro-packages the host composes, in declaration order.
  final List<ExternalMicroPackageReference> externalMicroPackages;
}

/// One `ExternalMicroPackage(...)` entry registered on `@KaiselInit`.
class ExternalMicroPackageReference {
  const ExternalMicroPackageReference({required this.module, this.import});

  /// The package's generated registry class, e.g. `FeatureShopKaiselModule`.
  final String module;

  /// Explicit import URI, or `null` to infer it from [module].
  final String? import;

  /// The manifest URI the host imports the package by: the one it was given, or
  /// the conventional `package:<name>/<name>.kaisel.dart` for a class named
  /// `<Name>KaiselModule`. `null` when neither can be derived.
  String? get importUri {
    if (import != null) {
      return import;
    }

    final base = module.endsWith('KaiselModule')
        ? module.substring(0, module.length - 'KaiselModule'.length)
        : module.endsWith('Module')
            ? module.substring(0, module.length - 'Module'.length)
            : null;
    if (base == null || base.isEmpty) {
      return null;
    }

    final package = toSnakeCase(base);
    return package.isEmpty ? null : 'package:$package/$package.kaisel.dart';
  }
}
