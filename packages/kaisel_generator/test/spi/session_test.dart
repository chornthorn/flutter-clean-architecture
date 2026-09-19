import 'package:kaisel_generator/src/model/generation_result.dart';
import 'package:kaisel_generator/src/spi/provider.dart';
import 'package:kaisel_generator/src/spi/provider_manager.dart';
import 'package:kaisel_generator/src/spi/session.dart';
import 'package:test/test.dart';

import 'support/fake_provider.dart';

void main() {
  KaiselSession sessionWith(Iterable<ProviderFactory<dynamic>> factories) => KaiselSession(
        providerManager: ProviderManager(spis: [fakeSpi], factories: factories),
      );

  test('should create a provider through the factory that serves the SPI', () {
    final factory = _RecordingFactory();
    final session = sessionWith([factory]);

    final provider = session.provider(fakeSpi);

    expect(factory.created, 1);
    expect(provider.session, same(session));
  });

  test('should create each provider once and reuse it', () {
    final factory = _RecordingFactory();
    final session = sessionWith([factory]);

    expect(session.provider(fakeSpi), same(session.provider(fakeSpi)));
    expect(factory.created, 1);
  });

  test('should ask the factories in order and return the first by default', () {
    final late = _RecordingFactory(id: 'late', order: 200);
    final first = _RecordingFactory(id: 'first', order: 10);
    final session = sessionWith([late, first]);

    expect((session.provider(fakeSpi)).session, same(session));
    expect(first.created, 1);
    expect(late.created, 0);
  });

  test('should create every provider of an SPI for providers()', () {
    final session = sessionWith([
      _RecordingFactory(id: 'a'),
      _RecordingFactory(id: 'b'),
    ]);

    expect(session.providers(fakeSpi), hasLength(2));
  });

  test('should report the ids registered for an SPI', () {
    final session = sessionWith([_RecordingFactory(id: 'a')]);

    expect(
      () => session.provider(fakeSpi, 'nope'),
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
      () => session.provider(fakeSpi),
      throwsA(isA<KaiselGenerationException>()),
    );
  });

  test('should close the providers it created', () {
    final session = sessionWith([_RecordingFactory()]);
    final provider = session.provider(fakeSpi);

    session.close();

    expect(provider.closeCount, 1);
  });
}

class _RecordingFactory implements ProviderFactory<FakeProvider> {
  _RecordingFactory({this.id = 'default', this.order = 0});

  @override
  final String id;

  @override
  final int order;

  /// How many providers this factory created.
  int created = 0;

  @override
  FakeProvider create(KaiselSession session) {
    created++;
    return FakeProvider(session);
  }
}
