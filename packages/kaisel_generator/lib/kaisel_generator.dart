/// Declarative annotations, metadata, and Dart FFI runner for Kaisel module registry code generation.
library;

import 'src/ffi/bindings.dart';

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
