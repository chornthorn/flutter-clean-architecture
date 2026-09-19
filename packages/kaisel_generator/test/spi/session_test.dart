import 'package:kaisel_generator/src/model/generation_result.dart';
import 'package:kaisel_generator/src/spi/emitter.dart';
import 'package:kaisel_generator/src/spi/session.dart';
import 'package:spi/spi.dart';
import 'package:test/test.dart';

/// [KaiselSession]'s own half of the framework: which factory a look-up picks, how
/// long a created provider lives, and what a failed look-up says. Registration and
/// ordering belong to `package:spi` and are tested there.
void main() {
  KaiselSession sessionWith(Iterable<ProviderFactory<dynamic>> factories) => KaiselSession(
        providerManager: ProviderManager(
          spis: const [ImportEmitterSpi.instance],
          factories: factories,
        ),
      );

  test('should create a provider through the factory that serves the SPI', () {
    final factory = _RecordingFactory();
    final session = sessionWith([factory]);

    final provider = session.provider(ImportEmitterSpi.instance) as _RecordingEmitter;

    expect(factory.created, 1);
    expect(provider.session, same(session));
  });

  test('should create each provider once and reuse it', () {
    final factory = _RecordingFactory();
    final session = sessionWith([factory]);

    expect(
      (session.provider(ImportEmitterSpi.instance) as _RecordingEmitter).session,
      same(session),
    );
    expect(factory.created, 1);
  });

  test('should ask the factories in order and return the first by default', () {
    final late = _RecordingFactory(id: 'late', order: 200);
    final first = _RecordingFactory(id: 'first', order: 10);
    final session = sessionWith([late, first]);

    expect(
      (session.provider(ImportEmitterSpi.instance) as _RecordingEmitter).session,
      same(session),
    );
    expect(first.created, 1);
    expect(late.created, 0);
  });

  test('should create every provider of an SPI for providers()', () {
    final session = sessionWith([
      _RecordingFactory(id: 'a'),
      _RecordingFactory(id: 'b'),
    ]);

    expect(session.providers(ImportEmitterSpi.instance), hasLength(2));
  });

  test('should report the ids registered for an SPI', () {
    final session = sessionWith([_RecordingFactory(id: 'a')]);

    expect(
      () => session.provider(ImportEmitterSpi.instance, 'nope'),
      throwsA(
        isA<KaiselGenerationException>().having(
          (error) => error.message,
          'message',
          allOf(contains('under id `nope`'), contains('Registered ids: a')),
        ),
      ),
    );
  });

  test('should report an SPI with no factory at all', () {
    final session = sessionWith(const []);

    expect(
      () => session.provider(ImportEmitterSpi.instance),
      throwsA(
        isA<KaiselGenerationException>().having(
          (error) => error.message,
          'message',
          'No Kaisel provider of `import-emitter` is registered.',
        ),
      ),
    );
  });

  test('should close the providers it created', () {
    final session = sessionWith([_RecordingFactory()]);
    final provider = session.provider(ImportEmitterSpi.instance) as _RecordingEmitter;

    session.close();

    expect(provider.closeCount, 1);
  });
}

class _RecordingFactory implements ImportEmitterFactory {
  _RecordingFactory({this.id = 'default', this.order = defaultProviderOrder});

  @override
  final String id;

  @override
  final int order;

  @override
  ProviderScope get scope => ProviderScope.session;

  /// How many providers this factory created.
  int created = 0;

  @override
  ImportEmitter create(ProviderSession session) {
    created++;
    return _RecordingEmitter(session);
  }
}

class _RecordingEmitter implements ImportEmitter {
  _RecordingEmitter(this.session);

  final ProviderSession session;

  /// How many times [close] was called.
  int closeCount = 0;

  @override
  void close() => closeCount++;

  @override
  Map<String, String> aliasesFor(List<String> keys, String prefix) => const {};

  @override
  void writeImports(StringBuffer buffer, List<({String uri, String alias})> aliasedImports) {}

  @override
  String packageUri({
    required String packageName,
    required String libDir,
    required String file,
  }) =>
      file;
}
