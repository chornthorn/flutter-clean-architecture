import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

typedef _KaiselGenerateC = Pointer<Utf8> Function(
  Pointer<Utf8> projectRoot,
  Pointer<Utf8> libDir,
  Pointer<Utf8> outputPath,
  Bool force,
);

typedef _KaiselGenerateDart = Pointer<Utf8> Function(
  Pointer<Utf8> projectRoot,
  Pointer<Utf8> libDir,
  Pointer<Utf8> outputPath,
  bool force,
);

typedef _KaiselFreeStringC = Void Function(Pointer<Utf8> ptr);
typedef _KaiselFreeStringDart = void Function(Pointer<Utf8> ptr);

/// Result of running the Kaisel code generation engine via FFI.
class KaiselGenerationResult {
  final bool success;
  final String? error;
  final int filesScanned;
  final int filesParsed;
  final int modulesCount;
  final int elapsedUs;
  final String? outputPath;

  const KaiselGenerationResult({
    required this.success,
    this.error,
    this.filesScanned = 0,
    this.filesParsed = 0,
    this.modulesCount = 0,
    this.elapsedUs = 0,
    this.outputPath,
  });

  factory KaiselGenerationResult.fromJson(Map<String, dynamic> json) {
    return KaiselGenerationResult(
      success: json['success'] as bool? ?? false,
      error: json['error'] as String?,
      filesScanned: (json['files_scanned'] as num?)?.toInt() ?? 0,
      filesParsed: (json['files_parsed'] as num?)?.toInt() ?? 0,
      modulesCount: (json['modules_count'] as num?)?.toInt() ?? 0,
      elapsedUs: (json['elapsed_us'] as num?)?.toInt() ?? 0,
      outputPath: json['output_path'] as String?,
    );
  }

  String get elapsedDisplay {
    if (elapsedUs >= 1000) {
      return '${(elapsedUs / 1000).toStringAsFixed(1)} ms';
    }
    return '$elapsedUs µs';
  }
}

/// Low-level FFI bindings to `libkaisel_generator`.
class KaiselBindings {
  static KaiselBindings? _instance;
  final DynamicLibrary _lib;
  late final _KaiselGenerateDart _generate;
  late final _KaiselFreeStringDart _freeString;

  KaiselBindings._(this._lib) {
    _generate = _lib
        .lookup<NativeFunction<_KaiselGenerateC>>('kaisel_generate')
        .asFunction<_KaiselGenerateDart>();
    _freeString = _lib
        .lookup<NativeFunction<_KaiselFreeStringC>>('kaisel_free_string')
        .asFunction<_KaiselFreeStringDart>();
  }

  /// Loads the dynamic library and returns the singleton bindings instance.
  static Future<KaiselBindings> load() async {
    if (_instance != null) return _instance!;

    final libraryPath = await _resolveDylibPath();
    final dylib = DynamicLibrary.open(libraryPath);
    _instance = KaiselBindings._(dylib);
    return _instance!;
  }

  static Future<String> _resolveDylibPath() async {
    final dylibName = Platform.isMacOS
        ? 'libkaisel_generator.dylib'
        : Platform.isWindows
            ? 'kaisel_generator.dll'
            : 'libkaisel_generator.so';

    // 1. Resolve package root
    final packageUri = await Isolate.resolvePackageUri(
      Uri.parse('package:kaisel_generator/kaisel_generator.dart'),
    );

    Directory? packageDir;
    if (packageUri != null && packageUri.scheme == 'file') {
      packageDir = File(packageUri.toFilePath()).parent.parent;
    }

    if (packageDir != null) {
      final releaseDylib = File('${packageDir.path}/target/release/$dylibName');
      if (releaseDylib.existsSync()) {
        return releaseDylib.path;
      }
      final debugDylib = File('${packageDir.path}/target/debug/$dylibName');
      if (debugDylib.existsSync()) {
        return debugDylib.path;
      }

      // If not built yet, build it via cargo
      final buildProcess = await Process.run(
        'cargo',
        ['build', '--release', '--manifest-path', '${packageDir.path}/Cargo.toml'],
      );
      if (buildProcess.exitCode == 0 && releaseDylib.existsSync()) {
        return releaseDylib.path;
      }
    }

    // 2. Fallback to default loader
    return dylibName;
  }

  KaiselGenerationResult generate({
    String? projectRoot,
    String? libDir,
    String? outputPath,
    bool force = false,
  }) {
    final rootPtr = projectRoot != null ? projectRoot.toNativeUtf8() : nullptr;
    final libPtr = libDir != null ? libDir.toNativeUtf8() : nullptr;
    final outPtr = outputPath != null ? outputPath.toNativeUtf8() : nullptr;

    try {
      final resultPtr = _generate(rootPtr, libPtr, outPtr, force);
      final jsonString = resultPtr.toDartString();
      _freeString(resultPtr);

      final Map<String, dynamic> map =
          jsonDecode(jsonString) as Map<String, dynamic>;
      return KaiselGenerationResult.fromJson(map);
    } finally {
      if (rootPtr != nullptr) calloc.free(rootPtr);
      if (libPtr != nullptr) calloc.free(libPtr);
      if (outPtr != nullptr) calloc.free(outPtr);
    }
  }
}
