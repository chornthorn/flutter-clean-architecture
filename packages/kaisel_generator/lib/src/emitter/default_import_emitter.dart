import 'package:path/path.dart' as p;

import '../spi/emitter.dart';
import '../spi/provider.dart';
import '../spi/session.dart';

/// The built-in [ImportEmitter].
///
/// Every generated file imports the modules it composes under an alias — `_i1`
/// for the host's own modules, `i1` inside a manifest, `_mp1` for the packages a
/// host composes — so two features that happen to pick the same symbol name
/// cannot collide. Aliases are assigned in the order the imports are registered,
/// and callers register the files sorted, so generated output does not depend on
/// the order the filesystem handed the files over.
class DefaultImportEmitter implements ImportEmitter {
  const DefaultImportEmitter();

  @override
  void close() {}

  @override
  Map<String, String> aliasesFor(List<String> keys, String prefix) => {
        for (var index = 0; index < keys.length; index++)
          keys[index]: '$prefix${index + 1}',
      };

  /// Writes `import '<uri>' as <alias>;` for each of [aliasedImports].
  @override
  void writeImports(StringBuffer buffer, List<({String uri, String alias})> aliasedImports) {
    for (final import in aliasedImports) {
      buffer.write("import '${import.uri}' as ${import.alias};\n");
    }
  }

  /// A `package:` import for a file inside the package, so generated code does
  /// not depend on where it sits relative to what it imports.
  ///
  /// Falls back to the file's own path when it lies outside [libDir] or the
  /// package name is unknown.
  @override
  String packageUri({
    required String packageName,
    required String libDir,
    required String file,
  }) {
    final posixFile = file.replaceAll(r'\', '/');
    if (packageName.isEmpty) {
      return posixFile;
    }

    final relative = p.relative(file, from: libDir).replaceAll(r'\', '/');
    if (relative == '..' || relative.startsWith('../')) {
      return posixFile;
    }

    return 'package:$packageName/$relative';
  }
}

/// Creates the built-in [ImportEmitter].
class DefaultImportEmitterFactory implements ImportEmitterFactory {
  const DefaultImportEmitterFactory();

  @override
  String get id => 'default';

  @override
  int get order => kaiselProviderOrder;

  @override
  ImportEmitter create(KaiselSession session) => const DefaultImportEmitter();
}
