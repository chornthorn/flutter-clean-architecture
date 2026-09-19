/// Declarative annotations, metadata, and Dart FFI runner for Kaisel module registry code generation.
library;

import 'src/ffi/bindings.dart';

// `lib/micro_mount.dart` is deliberately NOT exported here: it imports kaisel,
// and this library is the CLI's entrypoint — `dart run kaisel_generator` would
// then compile Flutter and fail under the plain Dart VM. Generated code imports
// it directly.
export 'src/annotations.dart';
export 'src/ffi/bindings.dart' show KaiselGenerationResult;

/// High-level Dart interface to the Rust-powered Kaisel code generator via Dart FFI.
class KaiselGenerator {
  /// Invokes the native generator directly in-process via Dart FFI.
  static Future<KaiselGenerationResult> generate({
    String? root,
    String? libDir,
    String? output,
    bool force = false,
  }) async {
    final bindings = await KaiselBindings.load();
    return bindings.generate(
      projectRoot: root,
      libDir: libDir,
      outputPath: output,
      force: force,
    );
  }
}
