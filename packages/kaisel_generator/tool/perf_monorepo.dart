/// Generates a throwaway monorepo into `.temp/perf` and times the generator on it.
///
/// The directory this writes is itself a host app root, mirroring the reference
/// app: host modules under `lib/features/`, one micro-package per feature under
/// `features/<name>/`, and `--routes` routes in every module. Sizing it up is
/// what makes a run do real work — registering N packages has the run generate N
/// manifests and compose N mounts on top of the host's own.
///
/// Usage, from `packages/kaisel_generator`:
///
///   dart run tool/perf_monorepo.dart                        # 25 packages x 10 routes
///   dart run tool/perf_monorepo.dart --packages 100 --routes 12 --runs 5
///   dart run tool/perf_monorepo.dart --analyze              # also type-checks the output
///   dart run tool/perf_monorepo.dart --out /tmp/perf --clean
///
/// Nothing here is committed: `.temp/` is git-ignored.
library;

import 'dart:io';

import 'package:kaisel_generator/kaisel_generator.dart';

Future<void> main(List<String> args) async {
  final options = _Options.parse(args);
  final repoRoot = _repoRoot();
  final outRoot = _absolute(repoRoot, options.out);

  if (options.clean) {
    if (Directory(outRoot).existsSync()) {
      Directory(outRoot).deleteSync(recursive: true);
      stdout.writeln('🧹 Removed $outRoot');
    } else {
      stdout.writeln('🧹 Nothing to remove at $outRoot');
    }
    return;
  }

  stdout.writeln('🦀 Performance fixture → $outRoot');
  final fixture = _Fixture(
    root: outRoot,
    repoRoot: repoRoot,
    packages: options.packages,
    hostModules: options.hostModules,
    routes: options.routes,
  );

  final writeStart = DateTime.now();
  final stats = fixture.write();
  final writeMs = DateTime.now().difference(writeStart).inMilliseconds;

  stdout.writeln(
    '   ${options.packages} micro-packages · ${options.hostModules} host modules · '
    '${options.routes} routes each · ${stats.files} files (${_kb(stats.bytes)}) '
    'written in $writeMs ms',
  );
  stdout.writeln('');

  final timings = <int>[];
  var result = const KaiselGenerationResult(success: true);
  for (var run = 1; run <= options.runs; run++) {
    result = await KaiselGenerator.generate(root: outRoot, force: true);
    if (!result.success) {
      stderr.writeln('❌ Run $run failed: ${result.error}');
      exitCode = 1;
      return;
    }
    timings.add(result.elapsedUs);
    stdout.writeln('   run $run: ${result.elapsedDisplay}');
  }

  timings.sort();
  final registry = File('$outRoot/lib/app/app_modules.g.dart');
  final mounted = registry
      .readAsLinesSync()
      .where((line) => line.startsWith('final class ') && line.contains('Mount '))
      .length;
  final expected = options.packages + options.hostModules;

  stdout.writeln('');
  stdout.writeln(
    '   best ${_ms(timings.first)} · median ${_ms(timings[timings.length ~/ 2])} · '
    'worst ${_ms(timings.last)}',
  );
  stdout.writeln(
    '   composed $mounted mounts from ${options.packages} micro-packages + '
    '${options.hostModules} host modules · '
    '${expected * options.routes} routes declared',
  );
  stdout.writeln(
    '   host scan: ${result.filesScanned} files (${result.filesParsed} parsed, '
    '${result.modulesCount} modules) — each package is scanned to write its manifest',
  );
  stdout.writeln(
    '   registry: ${_relative(repoRoot, registry.path)} (${_kb(registry.lengthSync())})',
  );

  if (mounted != expected) {
    stderr.writeln('\n❌ Expected $expected mounts, found $mounted in the registry.');
    exitCode = 1;
    return;
  }

  if (options.analyze) {
    stdout.writeln('');
    stdout.writeln('   flutter pub get + analyze…');
    final pub = Process.runSync('flutter', ['pub', 'get'], workingDirectory: outRoot);
    final analyze = pub.exitCode == 0
        ? Process.runSync('flutter', ['analyze'], workingDirectory: outRoot)
        : pub;
    if (analyze.exitCode != 0) {
      stderr.writeln(analyze.stdout);
      stderr.writeln(analyze.stderr);
      stderr.writeln('❌ The generated fixture does not analyze.');
      exitCode = 1;
      return;
    }
    stdout.writeln(
      '   generated registry + ${options.packages} manifests analyze clean',
    );
  }

  stdout.writeln('');
  stdout.writeln('   clean:    dart run tool/perf_monorepo.dart --clean');
  stdout.writeln('   analyze:  dart run tool/perf_monorepo.dart --analyze');
}

/// Arguments, all optional.
class _Options {
  const _Options({
    required this.packages,
    required this.hostModules,
    required this.routes,
    required this.runs,
    required this.out,
    required this.clean,
    required this.analyze,
  });

  final int packages;
  final int hostModules;
  final int routes;
  final int runs;
  final String out;
  final bool clean;
  final bool analyze;

  static _Options parse(List<String> args) {
    var packages = 25;
    var hostModules = 2;
    var routes = 10;
    var runs = 3;
    var out = '.temp/perf';
    var clean = false;
    var analyze = false;

    for (var i = 0; i < args.length; i++) {
      switch (args[i]) {
        case '--packages':
          packages = _intValue(args, ++i, '--packages');
        case '--host-modules':
          hostModules = _intValue(args, ++i, '--host-modules');
        case '--routes':
          routes = _intValue(args, ++i, '--routes');
        case '--runs':
          runs = _intValue(args, ++i, '--runs');
        case '--out':
          out = _value(args, ++i, '--out');
        case '--clean':
          clean = true;
        case '--analyze':
          analyze = true;
        default:
          stderr.writeln('Unknown argument: ${args[i]}');
          exit(64);
      }
    }

    if (routes < 3) {
      stderr.writeln('--routes must be at least 3 (home, detail, and one section).');
      exit(64);
    }

    return _Options(
      packages: packages,
      hostModules: hostModules,
      routes: routes,
      runs: runs,
      out: out,
      clean: clean,
      analyze: analyze,
    );
  }

  static String _value(List<String> args, int index, String name) {
    if (index >= args.length) {
      stderr.writeln('$name needs a value.');
      exit(64);
    }
    return args[index];
  }

  static int _intValue(List<String> args, int index, String name) {
    final value = int.tryParse(_value(args, index, name));
    if (value == null) {
      stderr.writeln('$name needs a number.');
      exit(64);
    }
    return value;
  }
}

/// The fixture files, written once per run of the script.
class _Fixture {
  _Fixture({
    required this.root,
    required this.repoRoot,
    required this.packages,
    required this.hostModules,
    required this.routes,
  });

  final String root;
  final String repoRoot;
  final int packages;
  final int hostModules;
  final int routes;

  int _files = 0;
  int _bytes = 0;

  ({int files, int bytes}) write() {
    final dir = Directory(root);
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
    dir.createSync(recursive: true);

    _write('pubspec.yaml', _hostPubspec());
    _write('kaisel.yaml', _kaiselYaml());
    _write('README.md', _readme());

    final imports = <String>[];
    final entries = <String>[];
    for (var i = 1; i <= packages; i++) {
      final name = 'feature$i';
      final module = 'Feature$i';
      _write('features/$name/pubspec.yaml', _featurePubspec(name));
      _write(
        'features/$name/lib/$name.dart',
        """
import 'package:kaisel_generator/kaisel_generator.dart';

@KaiselMicroPackage(moduleName: '$module')
void configure$module() {}
""",
      );
      _write(
        'features/$name/lib/${name}_module.dart',
        _moduleFile(module: module, prefix: '/$name', mount: '${module}Mount'),
      );
      imports.add("import 'package:$name/$name.kaisel.dart';");
      entries.add('    ExternalMicroPackage(${module}KaiselModule),');
    }

    for (var i = 1; i <= hostModules; i++) {
      _write(
        'lib/features/host$i/host${i}_module.dart',
        _moduleFile(module: 'Host$i', prefix: '/host$i', mount: 'Host${i}Mount'),
      );
    }

    _write('lib/app/app.dart', _hostApp(imports, entries));
    _write('.dart_tool/package_config.json', _packageConfig());

    return (files: _files, bytes: _bytes);
  }

  void _write(String relativePath, String content) {
    final file = File('$root/$relativePath');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
    _files++;
    _bytes += content.length;
  }

  String _hostPubspec() {
    final buffer = StringBuffer()
      ..writeln('name: perf_app')
      ..writeln('description: "Generated by tool/perf_monorepo.dart — do not commit."')
      ..writeln("publish_to: 'none'")
      ..writeln('version: 0.0.1')
      ..writeln()
      ..writeln('environment:')
      ..writeln('  sdk: ^3.13.0')
      ..writeln()
      ..writeln('dependencies:')
      ..writeln('  flutter:')
      ..writeln('    sdk: flutter')
      ..writeln('  kaisel: ^1.1.0')
      ..writeln('  kaisel_generator:')
      ..writeln('    path: ${_pathFrom(root, '$repoRoot/packages/kaisel_generator')}');
    for (var i = 1; i <= packages; i++) {
      buffer
        ..writeln('  feature$i:')
        ..writeln('    path: features/feature$i');
    }
    return buffer.toString();
  }

  String _featurePubspec(String name) => """
name: $name
description: "Generated performance fixture."
publish_to: 'none'
version: 0.0.1

environment:
  sdk: ^3.13.0

dependencies:
  flutter:
    sdk: flutter
  kaisel: ^1.1.0
  kaisel_generator:
    path: ${_pathFrom('$root/features/$name', '$repoRoot/packages/kaisel_generator')}
""";

  String _kaiselYaml() => """
output: lib/app/app_modules.g.dart
lib_dir: lib
route_class: AppRoute
""";

  String _hostApp(List<String> imports, List<String> entries) => """
import 'package:kaisel_generator/kaisel_generator.dart';

${imports.join('\n')}

import 'app_modules.g.dart';

// Public API export: exposes AppRoute, mounts, defaultAppCodec, etc.
export 'app_modules.g.dart';

@KaiselInit(
  externalMicroPackages: [
${entries.join('\n')}
  ],
)
void configureRouting() {}

final appRouterConfig = defaultAppRouterConfig;
""";

  String _packageConfig() {
    final entries = <String>[
      '  {"name":"perf_app","rootUri":"../","packageUri":"lib/","languageVersion":"3.13"}',
      for (var i = 1; i <= packages; i++)
        '  {"name":"feature$i","rootUri":"../features/feature$i","packageUri":"lib/","languageVersion":"3.13"}',
    ];
    return '{"configVersion":2,"packages":[\n${entries.join(',\n')}\n]}\n';
  }

  String _readme() => """
# Performance fixture

Generated by `packages/kaisel_generator/tool/perf_monorepo.dart`. Not committed.

- $packages micro-packages under `features/`, each declaring $routes routes
- $hostModules host modules under `lib/features/`
- `dart run tool/perf_monorepo.dart --clean` removes it

Regenerate with `dart run tool/perf_monorepo.dart` from `packages/kaisel_generator`.
To type-check the generated registry at this size, run `flutter pub get && flutter analyze`
here (it needs the pub cache; the fixture is written without running pub).
""";

  /// One route module file: a sealed family of [routes] routes, its codec, and the
  /// `@KaiselModule` that owns them.
  String _moduleFile({
    required String module,
    required String prefix,
    required String mount,
  }) {
    final codec = '${module}RouteCodec';
    final detail = '${module}Detail';
    final edit = '${module}Edit';
    final sections = [
      for (var i = 1; i <= routes - 3; i++) '${module}Section$i',
    ];

    final buffer = StringBuffer()
      ..writeln("import 'package:flutter/widgets.dart';")
      ..writeln("import 'package:kaisel/kaisel.dart';")
      ..writeln("import 'package:kaisel_generator/kaisel_generator.dart';")
      ..writeln()
      ..writeln('sealed class ${module}Route extends KaiselRoute {')
      ..writeln('  const ${module}Route();')
      ..writeln('}')
      ..writeln()
      ..writeln('final class ${module}Home extends ${module}Route {')
      ..writeln('  const ${module}Home();')
      ..writeln('}')
      ..writeln();

    for (final route in [detail, edit]) {
      buffer
        ..writeln('final class $route extends ${module}Route {')
        ..writeln('  const $route(this.id);')
        ..writeln('  final String id;')
        ..writeln('}')
        ..writeln();
    }
    for (final section in sections) {
      buffer
        ..writeln('final class $section extends ${module}Route {')
        ..writeln('  const $section([this.query]);')
        ..writeln('  final String? query;')
        ..writeln('}')
        ..writeln();
    }

    buffer
      ..writeln('class $codec extends ModuleStackCodec<${module}Route> {')
      ..writeln('  const $codec();')
      ..writeln()
      ..writeln('  @override')
      ..writeln('  List<String> encode(List<${module}Route> stack) => switch (stack.last) {')
      ..writeln('    ${module}Home() => const [],')
      ..writeln("    $detail(:final id) => ['detail', id],")
      ..writeln("    $edit(:final id) => ['edit', id],");
    for (var i = 0; i < sections.length; i++) {
      buffer.writeln(
        "    ${sections[i]}(:final query) => ['section${i + 1}', if (query != null) query],",
      );
    }
    buffer
      ..writeln('  };')
      ..writeln()
      ..writeln('  @override')
      ..writeln(
        '  List<${module}Route>? decode(List<String> segments) => switch (segments) {',
      )
      ..writeln('    [] => const [${module}Home()],')
      ..writeln("    ['detail', final id] => [const ${module}Home(), $detail(id)],")
      ..writeln("    ['edit', final id] => [const ${module}Home(), $edit(id)],");
    for (var i = 0; i < sections.length; i++) {
      final segment = i + 1;
      buffer
        ..writeln("    ['section$segment'] => const [${module}Home(), ${sections[i]}()],")
        ..writeln(
          "    ['section$segment', final query] => "
          '[const ${module}Home(), ${sections[i]}(query)],',
        );
    }
    buffer
      ..writeln('    _ => null,')
      ..writeln('  };')
      ..writeln('}')
      ..writeln()
      ..writeln("@KaiselModule(prefix: '$prefix', mount: '$mount')")
      ..writeln('class ${module}RouterModule extends RouteModule<${module}Route> {')
      ..writeln('  const ${module}RouterModule();')
      ..writeln()
      ..writeln('  @override')
      ..writeln(
        '  List<${module}Route> get initialStack => const [${module}Home()];',
      )
      ..writeln()
      ..writeln('  @override')
      ..writeln('  ModuleStackCodec<${module}Route> get codec => const $codec();')
      ..writeln()
      ..writeln('  @override')
      ..writeln(
        '  Widget buildPage(BuildContext context, ${module}Route route) => switch (route) {',
      )
      ..writeln("    ${module}Home() => const Center(child: Text('${module}Home')),")
      ..writeln("    $detail(:final id) => Center(child: Text('$detail \$id')),")
      ..writeln("    $edit(:final id) => Center(child: Text('$edit \$id')),");
    for (final section in sections) {
      buffer.writeln(
        "    $section(:final query) => Center(child: Text('$section \$query')),",
      );
    }
    buffer
      ..writeln('  };')
      ..writeln('}');

    return buffer.toString();
  }
}

/// `<repo>/packages/kaisel_generator/tool/perf_monorepo.dart` → `<repo>`.
String _repoRoot() {
  final script = Platform.script.toFilePath();
  final repo = File(script).parent.parent.parent.parent.path;
  if (Directory('$repo/packages/kaisel_generator').existsSync()) {
    return repo;
  }

  var dir = Directory.current;
  while (dir.path != dir.parent.path) {
    if (File('${dir.path}/packages/kaisel_generator/pubspec.yaml').existsSync()) {
      return dir.path;
    }
    dir = dir.parent;
  }
  stderr.writeln('Cannot find the repository root from $script.');
  exit(66);
}

String _absolute(String root, String path) =>
    path.startsWith('/') ? path : '$root/$path';

/// A relative path from one directory to another, or [to] when they share no
/// prefix (a fixture written outside the repository).
String _pathFrom(String from, String to) {
  final fromParts = from.split('/').where((part) => part.isNotEmpty).toList();
  final toParts = to.split('/').where((part) => part.isNotEmpty).toList();
  if (fromParts.isEmpty || toParts.isEmpty || fromParts.first != toParts.first) {
    return to;
  }

  var common = 0;
  while (common < fromParts.length &&
      common < toParts.length &&
      fromParts[common] == toParts[common]) {
    common++;
  }
  return [
    ...List.filled(fromParts.length - common, '..'),
    ...toParts.sublist(common),
  ].join('/');
}

String _relative(String root, String path) =>
    path.startsWith('$root/') ? path.substring(root.length + 1) : path;

String _kb(int bytes) => '${(bytes / 1024).toStringAsFixed(1)} KB';

String _ms(int microseconds) => '${(microseconds / 1000).toStringAsFixed(1)} ms';
