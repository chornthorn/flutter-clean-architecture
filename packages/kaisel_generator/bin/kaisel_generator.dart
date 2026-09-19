import 'dart:async';
import 'dart:io';

import 'package:kaisel_generator/kaisel_generator.dart';

Future<void> main(List<String> args) async {
  bool force = false;
  bool watch = false;
  String? root;
  String? lib;
  String? output;

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--force' || arg == '-f') {
      force = true;
    } else if (arg == '--watch' || arg == '-w') {
      watch = true;
    } else if ((arg == '--root' || arg == '-r') && i + 1 < args.length) {
      root = args[++i];
    } else if ((arg == '--lib' || arg == '-l') && i + 1 < args.length) {
      lib = args[++i];
    } else if ((arg == '--output' || arg == '-o') && i + 1 < args.length) {
      output = args[++i];
    }
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
