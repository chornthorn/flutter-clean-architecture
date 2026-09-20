import 'package:kaisel_generator/src/service/emitters.dart';
import 'package:test/test.dart';

void main() {
  const emitter = DefaultImportEmitter();

  group('aliasesFor', () {
    test('should number aliases in the order the keys were registered', () {
      expect(
        emitter.aliasesFor(['b.dart', 'a.dart'], '_i'),
        {'b.dart': '_i1', 'a.dart': '_i2'},
      );
    });

    test('should use the prefix the caller asked for', () {
      expect(emitter.aliasesFor(['a.dart'], 'i'), {'a.dart': 'i1'});
    });
  });

  group('writeImports', () {
    test('should write one aliased import per entry', () {
      final buffer = StringBuffer();
      emitter.writeImports(buffer, [
        (uri: 'package:kaisel/kaisel.dart', alias: '_mp1'),
        (uri: 'package:flutter_x/shop.dart', alias: '_i1'),
      ]);

      expect(
        buffer.toString(),
        "import 'package:kaisel/kaisel.dart' as _mp1;\n"
        "import 'package:flutter_x/shop.dart' as _i1;\n",
      );
    });
  });

  group('packageUri', () {
    test('should map a file under lib to a package URI', () {
      expect(
        emitter.packageUri(
          packageName: 'flutter_x',
          libDir: '/app/lib',
          file: '/app/lib/features/home/home_module.dart',
        ),
        'package:flutter_x/features/home/home_module.dart',
      );
    });

    test('should keep the path of a file outside lib', () {
      expect(
        emitter.packageUri(
          packageName: 'flutter_x',
          libDir: '/app/lib',
          file: '/other/x.dart',
        ),
        '/other/x.dart',
      );
    });

    test('should keep the path when the package name is unknown', () {
      expect(
        emitter.packageUri(
            packageName: '', libDir: '/app/lib', file: '/app/lib/x.dart'),
        '/app/lib/x.dart',
      );
    });
  });
}
