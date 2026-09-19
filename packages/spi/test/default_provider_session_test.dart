import 'package:spi/spi.dart';
import 'package:test/test.dart';

import 'provider_manager_test.dart' show FakeProvider, FakeProviderFactory, fakeSpi;

/// The loop every session needs: create once, cache, close what it created — and
/// never close what the manager owns.
void main() {
  ProviderManager managerWith(Iterable<ProviderFactory<dynamic>> factories) =>
      ProviderManager(spis: [fakeSpi], factories: factories);

  test('should create a provider on first ask and cache it', () {
    final factory = RecordingFactory();
    final session = DefaultProviderSession(providerManager: managerWith([factory]));

    final first = session.provider(fakeSpi);
    final second = session.provider(fakeSpi);

    expect(first, same(second));
    expect(factory.created, 1);
    expect(session.created, ['fake/default']);
  });

  test('should hand the session to the provider it creates', () {
    final session = DefaultProviderSession(providerManager: managerWith([RecordingFactory()]));

    expect(session.provider(fakeSpi).session, same(session));
  });

  test('should report an SPI it has no provider for', () {
    final session = DefaultProviderSession(providerManager: managerWith(const []));

    expect(
      () => session.provider(fakeSpi),
      throwsA(
        isA<ProviderException>().having(
          (error) => error.message,
          'message',
          'No provider of `fake` is registered.',
        ),
      ),
    );
  });

  test('should report an id it has no provider for', () {
    final session = DefaultProviderSession(providerManager: managerWith([RecordingFactory()]));

    expect(
      () => session.provider(fakeSpi, 'nope'),
      throwsA(isA<ProviderException>().having((error) => error.message, 'message', contains('`nope`'))),
    );
  });

  test('should close what it created, innermost first', () {
    final first = RecordingFactory(id: 'first', order: 10);
    final second = RecordingFactory(id: 'second', order: 20);
    final session = DefaultProviderSession(providerManager: managerWith([first, second]));

    session.providers(fakeSpi);
    session.close();

    expect(first.provider.closeCount, 1);
    expect(second.provider.closeCount, 1);
    expect(session.created, isEmpty);
  });

  test('should create the same application-scoped provider for every session', () {
    final factory = RecordingFactory(scope: ProviderScope.application);
    final manager = managerWith([factory]);

    final first = DefaultProviderSession(providerManager: manager).provider(fakeSpi);
    final second = DefaultProviderSession(providerManager: manager).provider(fakeSpi);

    expect(first, same(second));
    expect(factory.created, 1);
  });

  test('should not close an application-scoped provider when a session closes', () {
    final factory = RecordingFactory(scope: ProviderScope.application);
    final manager = managerWith([factory]);
    final session = DefaultProviderSession(providerManager: manager);

    session.provider(fakeSpi);
    session.close();

    expect(factory.provider.closeCount, 0);

    manager.close();

    expect(factory.provider.closeCount, 1);
  });
}

/// A factory whose provider counts what happened to it.
class RecordingFactory implements FakeProviderFactory {
  RecordingFactory({
    this.id = 'default',
    this.order = defaultProviderOrder,
    this.scope = ProviderScope.session,
  });

  @override
  final String id;

  @override
  final int order;

  @override
  final ProviderScope scope;

  /// How many providers this factory created.
  int created = 0;

  /// The provider it created last — the one a test inspects.
  late FakeProvider provider;

  @override
  FakeProvider create(ProviderSession session) {
    created++;
    return provider = FakeProvider(session);
  }
}
