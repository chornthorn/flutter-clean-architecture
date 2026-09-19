import 'package:spi/spi.dart';
import 'package:test/test.dart';

void main() {
  test('should file a factory under the SPI that accepts it', () {
    final manager = ProviderManager(
      spis: [fakeSpi],
      factories: [const FakeFactory(id: 'a')],
    );

    expect(manager.spiOf(const FakeFactory(id: 'a')), same(fakeSpi));
    expect(manager.factoriesFor(fakeSpi), hasLength(1));
  });

  test('should reject a factory no registered SPI accepts', () {
    expect(
      () => ProviderManager(spis: [fakeSpi], factories: [const OrphanFactory()]),
      throwsA(
        isA<ProviderException>().having(
          (error) => error.message,
          'message',
          allOf(contains('No SPI accepts'), contains('orphan'), contains('fake')),
        ),
      ),
    );
  });

  test('should ask factories in order, then in registration order', () {
    final manager = ProviderManager(
      spis: [fakeSpi],
      factories: const [
        FakeFactory(id: 'built-in'),
        FakeFactory(id: 'late', order: 200),
        FakeFactory(id: 'first', order: 10),
      ],
    );

    expect(
      manager.factoriesFor(fakeSpi).map((factory) => factory.id),
      ['first', 'built-in', 'late'],
    );
  });

  test('should keep registration order for factories of equal order', () {
    final manager = ProviderManager(
      spis: [fakeSpi],
      factories: const [
        FakeFactory(id: 'a', order: 50),
        FakeFactory(id: 'b', order: 50),
        FakeFactory(id: 'c', order: 50),
      ],
    );

    expect(
      manager.factoriesFor(fakeSpi).map((factory) => factory.id),
      ['a', 'b', 'c'],
    );
  });

  test('should find a factory by id, or the first one without an id', () {
    final manager = ProviderManager(
      spis: [fakeSpi],
      factories: const [
        FakeFactory(id: 'a', order: 20),
        FakeFactory(id: 'b', order: 10),
      ],
    );

    expect(manager.factoryFor(fakeSpi)?.id, 'b');
    expect(manager.factoryFor(fakeSpi, 'a')?.id, 'a');
    expect(manager.factoryFor(fakeSpi, 'nope'), isNull);
  });

  test('should keep the SPIs it was given', () {
    final manager = ProviderManager(spis: [fakeSpi], factories: const []);

    expect(manager.spis, [same(fakeSpi)]);
    expect(manager.factoriesFor(fakeSpi), isEmpty);
  });
}

/// An SPI to exercise registration and lookup without a real capability in the
/// way. Canonical, so a test can ask for the very instance it registered with.
const fakeSpi = _FakeSpi();

class _FakeSpi implements Spi<FakeProvider> {
  const _FakeSpi();

  @override
  String get name => 'fake';

  @override
  bool accepts(ProviderFactory<dynamic> factory) => factory is FakeProviderFactory;
}

/// A provider that records who created it and whether it was closed.
class FakeProvider implements Provider {
  FakeProvider(this.session);

  final ProviderSession session;

  /// How many times [close] was called.
  int closeCount = 0;

  @override
  void close() => closeCount++;
}

/// The factories of [fakeSpi] — the marker interface every SPI pairs with its
/// provider, as `Spi.accepts` checks.
abstract interface class FakeProviderFactory implements ProviderFactory<FakeProvider> {}

class FakeFactory implements FakeProviderFactory {
  const FakeFactory({required this.id, this.order = defaultProviderOrder});

  @override
  final String id;

  @override
  final int order;

  @override
  ProviderScope get scope => ProviderScope.session;

  @override
  FakeProvider create(ProviderSession session) => FakeProvider(session);
}

/// A factory of no registered SPI, to prove registration is checked.
class OrphanFactory implements ProviderFactory<FakeProvider> {
  const OrphanFactory();

  @override
  String get id => 'orphan';

  @override
  int get order => 0;

  @override
  ProviderScope get scope => ProviderScope.session;

  @override
  FakeProvider create(ProviderSession session) => FakeProvider(session);
}
