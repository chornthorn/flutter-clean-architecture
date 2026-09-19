import 'dart:io';

import 'package:path/path.dart' as p;

/// A throwaway project tree under the system temp directory.
///
/// The generator reads and writes real files, so its tests build real projects:
/// a directory with the `pubspec.yaml`, `lib/` sources and
/// `.dart_tool/package_config.json` the case needs.
class TempProject {
  TempProject._(this.root);

  factory TempProject.create(String label) => TempProject._(
        Directory.systemTemp.createTempSync('kaisel_${label}_').path,
      );

  /// Absolute path of the project root.
  final String root;

  String path(String relative) => p.join(root, relative);

  Directory directory(String relative) => Directory(path(relative));

  void write(String relative, String content) {
    final file = File(path(relative));
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(content);
  }

  String read(String relative) => File(path(relative)).readAsStringSync();

  bool exists(String relative) => File(path(relative)).existsSync();

  void delete() => Directory(root).deleteSync(recursive: true);
}
