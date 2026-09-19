import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';

import '../model/generation_result.dart';
import '../model/kaisel_config.dart';
import '../spi/provider.dart';
import '../spi/scanner.dart';
import '../spi/session.dart';

/// The built-in [ProjectScanner]: `kaisel.yaml` and `pubspec.yaml` read from the
/// project root, and `package:` imports resolved through the project's own
/// `.dart_tool/package_config.json`.
///
/// A manifest is named by convention (`package:profile/profile.kaisel.dart`) and
/// lives in another package, so it is resolved through the package config rather
/// than guessed at.
class DefaultProjectScanner implements ProjectScanner {
  const DefaultProjectScanner();

  @override
  void close() {}

  @override
  KaiselConfig? readConfig(String root) {
    final file = File(p.join(root, 'kaisel.yaml'));
    if (!file.existsSync()) {
      return null;
    }

    final Object? document = _loadYaml(file);
    if (document is! Map) {
      return const KaiselConfig();
    }

    return KaiselConfig(
      output: _string(document, 'output'),
      routeClass: _string(document, 'route_class'),
      initialRoute: _string(document, 'initial_route'),
      libDir: _string(document, 'lib_dir'),
    );
  }

  @override
  String? readPackageName(String root) {
    final file = File(p.join(root, 'pubspec.yaml'));
    if (!file.existsSync()) {
      return null;
    }

    final Object? document = _loadYaml(file);
    if (document is! Map) {
      return null;
    }

    final name = document['name'];
    return name is String && name.isNotEmpty ? name : null;
  }

  @override
  String resolveImportUri({
    required String root,
    required String outputDir,
    required String importUri,
  }) {
    if (importUri.startsWith('package:')) {
      final rest = importUri.substring('package:'.length);
      final separator = rest.indexOf('/');
      if (separator <= 0) {
        throw KaiselGenerationException(
          'Invalid micro-package import `$importUri`: expected '
          '`package:<name>/<path>`.',
        );
      }
      final package = rest.substring(0, separator);
      final path = rest.substring(separator + 1);
      return p.normalize(p.join(resolvePackageLibDir(root: root, package: package), path));
    }

    if (importUri.startsWith('file:')) {
      return p.normalize(Uri.parse(importUri).toFilePath());
    }

    if (p.isAbsolute(importUri)) {
      return p.normalize(importUri);
    }

    return p.normalize(p.join(outputDir, importUri));
  }

  @override
  String resolvePackageLibDir({required String root, required String package}) {
    final configPath = p.join(root, '.dart_tool', 'package_config.json');
    final configFile = File(configPath);
    if (!configFile.existsSync()) {
      throw KaiselGenerationException(
        'Could not read `$configPath` to resolve `package:$package`. '
        'Run `dart pub get` in the project.',
      );
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(configFile.readAsStringSync());
    } on FormatException catch (error) {
      throw KaiselGenerationException('Invalid `$configPath`: ${error.message}');
    }
    if (decoded is! Map<String, Object?> || decoded['packages'] is! List) {
      throw KaiselGenerationException('Invalid `$configPath`: no `packages` list.');
    }

    for (final entry in decoded['packages']! as List<Object?>) {
      if (entry is! Map<String, Object?> || entry['name'] != package) {
        continue;
      }

      final rootUri = entry['rootUri'];
      if (rootUri is! String) {
        throw KaiselGenerationException('Invalid `$configPath`: `$package` has no rootUri.');
      }
      // A path dependency's `rootUri` is relative to the package config's own
      // directory (`.dart_tool/`), so `../features/profile` resolves upward.
      final packageRoot = rootUri.startsWith('file:')
          ? Uri.parse(rootUri).toFilePath()
          : p.join(p.dirname(configPath), rootUri);
      final packageUri = entry['packageUri'] as String? ?? 'lib/';

      return p.normalize(p.join(packageRoot, packageUri));
    }

    throw KaiselGenerationException(
      'Package `$package` is not declared in `$configPath`. Add it to the '
      "project's pubspec.yaml and run `dart pub get`.",
    );
  }

  Object? _loadYaml(File file) {
    try {
      return loadYaml(file.readAsStringSync());
    } on FileSystemException catch (error) {
      throw KaiselGenerationException('Could not read `${file.path}`: ${error.message}');
    } on YamlException catch (error) {
      throw KaiselGenerationException('Invalid `${file.path}`: ${error.message}');
    }
  }

  static String? _string(Map<Object?, Object?> document, String key) {
    final value = document[key];
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  }
}

/// Creates the built-in [ProjectScanner].
class DefaultProjectScannerFactory implements ProjectScannerFactory {
  const DefaultProjectScannerFactory();

  @override
  String get id => 'default';

  @override
  int get order => kaiselProviderOrder;

  @override
  ProjectScanner create(KaiselSession session) => const DefaultProjectScanner();
}
