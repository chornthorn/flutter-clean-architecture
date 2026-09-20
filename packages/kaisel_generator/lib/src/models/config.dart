/// What a project configures: its `kaisel.yaml`, its `@KaiselInit` entry point,
/// and the project those two resolve to.
///
/// Plain values read from a project, so a test can assert on them without a build.
library;

import '../helper/naming.dart';

/// The keys `kaisel.yaml` may set.
///
/// A `kaisel.yaml` is optional — a project that configures everything through
/// `@KaiselInit` needs none — but when the file is there it is read as YAML, so
/// quotes, comments and key order behave the way a reader expects.
class KaiselConfig {
  const KaiselConfig({
    this.output,
    this.routeClass,
    this.initialRoute,
    this.libDir,
  });

  /// Path of the generated registry, relative to the project root.
  final String? output;

  /// Name of the host's sealed route class.
  final String? routeClass;

  /// Mount the host lands on, overriding `isInitial`.
  final String? initialRoute;

  /// Directory to scan, relative to the project root.
  final String? libDir;
}

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

/// The project a generation run works against, after its configuration has been
/// resolved.
///
/// The raw inputs (`--root`, `--lib`, `--output`) become these values once
/// `kaisel.yaml`, `@KaiselInit` and the conventions have had their say, so every
/// later step reads one resolved project rather than re-deriving paths.
class ProjectContext {
  const ProjectContext({
    required this.root,
    required this.libDir,
    required this.outputPath,
    required this.packageName,
    required this.write,
    this.config,
  });

  /// Absolute path of the project root.
  final String root;

  /// Directory the sources are scanned in.
  final String libDir;

  /// Where this run's output file goes.
  final String outputPath;

  /// The package's name, e.g. `flutter_x`.
  final String packageName;

  /// Whether the caller wants the output written, or its source handed back.
  final bool write;

  /// The project's `kaisel.yaml`, when it has one.
  final KaiselConfig? config;
}
