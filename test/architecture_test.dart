import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Layer rules as import constraints, so the structure cannot rot quietly.
// See docs/architecture.md.
void main() {
  const featureRules = <String, List<String>>{
    // Domain: entities, use cases, and the contracts they need. Plain Dart apart
    // from injectify's `@Injectable`, which is itself pure Dart.
    'domain': [
      'package:flutter',
      'package:get_it',
      'dependency_container.dart',
      'infrastructure/',
      'presentation/',
    ],
    // The UI is constructor-injected by a provider in the router, so it never
    // reaches for the container, an adapter, or a repository contract.
    'presentation': [
      'package:get_it',
      'dependency_container.dart',
      'infrastructure/',
      'domain/repositories/',
    ],
  };

  featureRules.forEach((layer, forbidden) {
    test('should keep features/*/$layer free of ${forbidden.join(', ')}', () {
      _expectNoForbiddenImports(
        _featureFilesIn(layer),
        forbidden,
        describedAs: 'lib/features/*/$layer/',
      );
    });
  });

  test('should keep core free of features', () {
    _expectNoForbiddenImports(_dartFilesUnder('lib/core'), [
      'features/',
    ], describedAs: 'lib/core/');
  });
}

void _expectNoForbiddenImports(
  Iterable<File> files,
  List<String> forbidden, {
  required String describedAs,
}) {
  final offenders = <String>[];
  var scanned = 0;

  for (final file in files) {
    scanned++;
    for (final uri in _importsOf(file)) {
      if (forbidden.any(uri.contains)) {
        offenders.add('${file.path} imports $uri');
      }
    }
  }

  // Guards against the check silently passing because it looked at nothing.
  expect(
    scanned,
    greaterThan(0),
    reason: 'No files found under $describedAs — are these paths right?',
  );

  expect(offenders, isEmpty, reason: 'Offending imports: $offenders');
}

// Every .dart file under lib/features/<feature>/<layer>/.
Iterable<File> _featureFilesIn(String layer) sync* {
  final features = Directory('lib/features').listSync().whereType<Directory>();
  for (final feature in features) {
    yield* _dartFilesUnder('${feature.path}/$layer');
  }
}

// Every .dart file beneath path, recursively. Empty if it doesn't exist.
Iterable<File> _dartFilesUnder(String path) sync* {
  final directory = Directory(path);
  if (!directory.existsSync()) return;

  for (final entity in directory.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) yield entity;
  }
}

// Every URI a Dart file imports.
Iterable<String> _importsOf(File file) {
  final importPattern = RegExp(r"""^import\s+'([^']+)';""", multiLine: true);
  return importPattern
      .allMatches(file.readAsStringSync())
      .map((match) => match.group(1)!);
}
