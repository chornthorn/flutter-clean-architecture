import 'dart:async';
import 'dart:io';

import 'package:kaisel_generator/kaisel_generator.dart';

Future<void> main(List<String> args) async {
  bool force = false;
  bool watch = false;
  bool clean = false;
  String? root;
  String? lib;
  String? output;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--force' || arg == '-f') {
      force = true;
    } else if (arg == '--watch' || arg == '-w') {
      watch = true;
    } else if (arg == '--clean') {
      clean = true;
    } else if ((arg == '--root' || arg == '-r') && i + 1 < args.length) {
      root = args[++i];
    } else if ((arg == '--lib' || arg == '-l') && i + 1 < args.length) {
      lib = args[++i];
    } else if ((arg == '--output' || arg == '-o') && i + 1 < args.length) {
      output = args[++i];
    }
  }

  if (clean) {
    final projectRoot = root ?? Directory.current.path;
    final removed = _cleanGenerated(projectRoot, output);
    stdout.writeln('🧹 Removed $removed generated file(s) under $projectRoot');
    return;
  }

  stdout.writeln('🦀 Kaisel Module Registry Generator (Dart FFI)');
  final result = await KaiselGenerator.generate(
    root: root,
    libDir: lib,
    output: output,
    force: force,
  );

  if (!result.success) {
    stderr.writeln('❌ Error: ${result.error ?? "Unknown error"}');
    exit(1);
  }

  stdout.writeln(
    '⚡ Generated ${result.modulesCount} mounts from ${result.modulesCount} modules '
    '(${result.filesScanned} files scanned, ${result.filesParsed} parsed) in ${result.elapsedDisplay}',
  );
  if (result.outputPath != null) {
    stdout.writeln('   Output: ${result.outputPath}');
  }

  if (watch) {
    final scanDir = lib != null ? Directory(lib) : Directory('lib');
    stdout.writeln('\n👀 Watching for changes in ${scanDir.path} via Dart...');

    DateTime lastRun = DateTime.now();
    await for (final event in scanDir.watch(recursive: true)) {
      if (event.path.endsWith('.dart') && !event.path.endsWith('.g.dart')) {
        if (DateTime.now().difference(lastRun).inMilliseconds > 150) {
          lastRun = DateTime.now();
          final r = await KaiselGenerator.generate(
            root: root,
            libDir: lib,
            output: output,
            force: false,
          );
          if (r.success) {
            stdout.writeln('⚡ Re-generated via FFI in ${r.elapsedDisplay}');
          } else {
            stderr.writeln('❌ Error: ${r.error}');
          }
        }
      }
    }
  }
}

/// Deletes the host registry and every micro-package manifest under [root].
///
/// Generated sources are never committed, so removing them is always safe —
/// this is the counterpart of `build_runner clean`, which leaves
/// `build_to: source` outputs (like the registry) in place.
int _cleanGenerated(String root, String? explicitOutput) {
  var removed = 0;

  final registry = File('$root/${explicitOutput ?? _configuredOutput(root)}');
  if (registry.existsSync()) {
    registry.deleteSync();
    removed++;
  }

  for (final file in _generatedManifests(Directory(root))) {
    file.deleteSync();
    removed++;
  }
  return removed;
}

/// The `output:` of `kaisel.yaml`, or the generator's default.
String _configuredOutput(String root) {
  final config = File('$root/kaisel.yaml');
  if (config.existsSync()) {
    for (final line in config.readAsLinesSync()) {
      final trimmed = line.trim();
      if (trimmed.startsWith('output:')) {
        final value = trimmed.substring('output:'.length).trim();
        if (value.isNotEmpty) {
          return value;
        }
      }
    }
  }
  return 'lib/app/app_modules.g.dart';
}

/// Every `*.kaisel.dart` under [dir], skipping the directories that never hold
/// generated sources.
Iterable<File> _generatedManifests(Directory dir) sync* {
  const skipped = {'.dart_tool', '.git', '.temp', 'build', 'target'};
  for (final entity in dir.listSync(followLinks: false)) {
    final name = entity.uri.pathSegments.where((s) => s.isNotEmpty).last;
    if (entity is Directory) {
      if (skipped.contains(name)) {
        continue;
      }
      yield* _generatedManifests(entity);
    } else if (entity is File && name.endsWith('.kaisel.dart')) {
      yield entity;
    }
  }
}
