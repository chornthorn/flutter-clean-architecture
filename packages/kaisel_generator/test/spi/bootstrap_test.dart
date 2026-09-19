import 'package:kaisel_generator/kaisel_generator.dart';
import 'package:path/path.dart' as p;
import 'package:spi/spi.dart';
import 'package:test/test.dart';

import '../support/temp_project.dart';

/// The extension seam: a package that ships a provider depends on `package:spi`
/// and implements the interface it extends — it never names the generator's
/// internals. `KaiselBootstrap` is where such a factory is registered, and a
/// lower `order` is what puts it in front of the built-in provider.
void main() {
  test('should serve a request with a provider the entry point registered', () async {
    final project = TempProject.create('custom_emitter');
    addTearDown(project.delete);
    project.write('lib/app/app.dart', '''
@KaiselInit()
void configureRouting() {}
''');
    project.write('lib/features/home/home_module.dart', '''
@KaiselModule(isInitial: true)
class HomeRouterModule extends RouteModule<HomeRoute> {
  const HomeRouterModule();
}
''');

    final emitter = _SampleImportEmitterFactory();
    final generator = KaiselBootstrap(
      providerFactories: [emitter, ...kaiselProviderFactories],
    ).createGenerator();

    final result = await generator.generate(root: project.root, force: true);

    expect(result.success, isTrue, reason: result.error);
    expect(emitter.created, 1, reason: 'the registered factory is asked first');

    final registry = project.read('lib/app/app_modules.g.dart');
    expect(registry, contains('// imports by the sample provider'));
    // The registry emitter still composes its own imports with the aliases the
    // SPI handed back — the provider replaced the emitter, not the pipeline.
    expect(registry, contains('as _i1;'));
  });
}

/// A third-party [ImportEmitter], implemented against `package:spi` alone.
class _SampleImportEmitter implements ImportEmitter {
  @override
  void close() {}

  @override
  Map<String, String> aliasesFor(List<String> keys, String prefix) => {
        for (var index = 0; index < keys.length; index++) keys[index]: '$prefix${index + 1}',
      };

  @override
  void writeImports(StringBuffer buffer, List<({String uri, String alias})> aliasedImports) {
    buffer.write('// imports by the sample provider\n');
    for (final import in aliasedImports) {
      buffer.write("import '${import.uri}' as ${import.alias};\n");
    }
  }

  @override
  String packageUri({
    required String packageName,
    required String libDir,
    required String file,
  }) =>
      'package:$packageName/${p.relative(file, from: libDir).replaceAll(r'\', '/')}';
}

class _SampleImportEmitterFactory implements ImportEmitterFactory {
  /// How many providers this factory created.
  int created = 0;

  @override
  String get id => 'sample';

  /// Before the built-in emitter, so the session asks this one first.
  @override
  int get order => 10;

  @override
  ProviderScope get scope => ProviderScope.session;

  @override
  ImportEmitter create(ProviderSession session) {
    created++;
    return _SampleImportEmitter();
  }
}
