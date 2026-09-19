import 'package:kaisel_generator/src/model/generation_result.dart';
import 'package:kaisel_generator/src/spi/bootstrap.dart';
import 'package:kaisel_generator/src/spi/provider_manager.dart';
import 'package:test/test.dart';

import 'support/fake_provider.dart';

void main() {
  test('should register a factory under the SPI that accepts it', () {
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
        isA<KaiselGenerationException>().having(
          (error) => error.message,
          'message',
          allOf(contains('No Kaisel SPI accepts'), contains('orphan')),
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

  test('should find a factory by id, or the first one without an id', () {
    final manager = ProviderManager(
      spis: [fakeSpi],
      factories: const [FakeFactory(id: 'a', order: 20), FakeFactory(id: 'b', order: 10)],
    );

    expect(manager.factoryFor(fakeSpi)?.id, 'b');
    expect(manager.factoryFor(fakeSpi, 'a')?.id, 'a');
    expect(manager.factoryFor(fakeSpi, 'nope'), isNull);
  });

  group('the SPIs Kaisel ships', () {
    test('should accept exactly the factories Kaisel ships', () {
      for (final factory in kaiselProviderFactories) {
        final accepting = [
          for (final spi in kaiselSpis)
            if (spi.accepts(factory)) spi.name,
        ];
        expect(accepting, hasLength(1), reason: '${factory.id} -> $accepting');
      }
    });

    test('should each have at least one factory', () {
      final manager = ProviderManager(
        spis: kaiselSpis,
        factories: kaiselProviderFactories,
      );

      for (final spi in kaiselSpis) {
        expect(manager.factoriesFor(spi), isNotEmpty, reason: spi.name);
      }
    });

    test('should be registered with a session factory', () {
      final sessionFactory = const KaiselBootstrap().createSessionFactory();

      expect(sessionFactory.spis, hasLength(kaiselSpis.length));
      expect(
        sessionFactory.factoriesFor(kaiselSpis.last).map((factory) => factory.id),
        contains('host-registry'),
      );
    });
  });
}
