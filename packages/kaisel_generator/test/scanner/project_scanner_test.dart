import 'package:kaisel_generator/src/model/generation_result.dart';
import 'package:kaisel_generator/src/scanner/default_project_scanner.dart';
import 'package:test/test.dart';

import '../support/temp_project.dart';

void main() {
  const scanner = DefaultProjectScanner();

  group('readConfig', () {
    test('should read the keys kaisel.yaml sets', () {
      final project = TempProject.create('kaisel_yaml');
      addTearDown(project.delete);
      project.write('kaisel.yaml', '''
# Kaisel Code Generator Configuration
output: lib/app/app_modules.g.dart
lib_dir: lib
route_class: AppRoute
initial_route: HomeMount
''');

      final config = scanner.readConfig(project.root);

      expect(config, isNotNull);
      expect(config!.output, 'lib/app/app_modules.g.dart');
      expect(config.libDir, 'lib');
      expect(config.routeClass, 'AppRoute');
      expect(config.initialRoute, 'HomeMount');
    });

    test('should return null when the project has no kaisel.yaml', () {
      final project = TempProject.create('no_kaisel_yaml');
      addTearDown(project.delete);

      expect(scanner.readConfig(project.root), isNull);
    });
  });

  group('readPackageName', () {
    test('should read the name from pubspec.yaml', () {
      final project = TempProject.create('pubspec_name');
      addTearDown(project.delete);
      project.write('pubspec.yaml', 'name: flutter_x\nversion: 0.1.0\n');

      expect(scanner.readPackageName(project.root), 'flutter_x');
    });

    test('should return null when the package has no pubspec', () {
      final project = TempProject.create('no_pubspec');
      addTearDown(project.delete);

      expect(scanner.readPackageName(project.root), isNull);
    });
  });

  group('resolveImportUri', () {
    test('should resolve a relative import against the output directory', () {
      expect(
        scanner.resolveImportUri(
          root: '/app',
          outputDir: '/app/lib/app',
          importUri: '../feature.kaisel.dart',
        ),
        '/app/lib/feature.kaisel.dart',
      );
    });

    test('should resolve a package import through the package config', () {
      final project = TempProject.create('package_config');
      addTearDown(project.delete);

      project.write('pubspec.yaml', 'name: flutter_x\n');
      project.write('features/feature_shop/pubspec.yaml', 'name: feature_shop\n');
      project.write(
        '.dart_tool/package_config.json',
        '''
{
  "configVersion": 2,
  "packages": [
    {"name": "flutter_x", "rootUri": "../", "packageUri": "lib/", "languageVersion": "3.0"},
    {"name": "feature_shop", "rootUri": "../features/feature_shop", "packageUri": "lib/", "languageVersion": "3.0"},
    {"name": "hosted_shop", "rootUri": "file:///pub-cache/hosted_shop-1.0.0", "packageUri": "lib/", "languageVersion": "3.0"}
  ]
}
''',
      );

      // A path dependency's rootUri is relative to the package config's
      // directory, so its `.`/`..` components must not survive.
      expect(
        scanner.resolveImportUri(
          root: project.root,
          outputDir: project.path('lib/app'),
          importUri: 'package:feature_shop/feature_shop.kaisel.dart',
        ),
        project.path('features/feature_shop/lib/feature_shop.kaisel.dart'),
      );

      expect(
        scanner.resolveImportUri(
          root: project.root,
          outputDir: project.path('lib/app'),
          importUri: 'package:hosted_shop/src/shop.kaisel.dart',
        ),
        '/pub-cache/hosted_shop-1.0.0/lib/src/shop.kaisel.dart',
      );
    });

    test('should tell the reader to run pub get when the package is unknown', () {
      final project = TempProject.create('missing_package_config');
      addTearDown(project.delete);
      project.write('pubspec.yaml', 'name: flutter_x\n');

      expect(
        () => scanner.resolveImportUri(
          root: project.root,
          outputDir: project.path('lib/app'),
          importUri: 'package:feature_shop/feature_shop.kaisel.dart',
        ),
        throwsA(
          isA<KaiselGenerationException>().having(
            (error) => error.message,
            'message',
            contains('dart pub get'),
          ),
        ),
      );
    });

    test('should reject an import that is not package:name/path', () {
      expect(
        () => scanner.resolveImportUri(
          root: '/app',
          outputDir: '/app/lib/app',
          importUri: 'package:feature_shop',
        ),
        throwsA(isA<KaiselGenerationException>()),
      );
    });
  });
}
