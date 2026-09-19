import 'package:kaisel_generator/src/spi/provider.dart';
import 'package:kaisel_generator/src/spi/session.dart';
import 'package:kaisel_generator/src/spi/spi.dart';

/// A minimal SPI to exercise registration and lookup without Kaisel's own
/// providers in the way.
Spi<FakeProvider> get fakeSpi => _FakeSpi();

/// A provider that records whether it was closed.
class FakeProvider implements Provider {
  FakeProvider(this.session);

  final KaiselSession session;

  /// How many times [close] was called.
  int closeCount = 0;

  @override
  void close() => closeCount++;
}

class _FakeSpi implements Spi<FakeProvider> {
  @override
  String get name => 'fake';

  @override
  bool accepts(ProviderFactory<dynamic> factory) => factory is FakeFactory;
}

/// Creates [FakeProvider]s under the id and order it was given.
class FakeFactory implements ProviderFactory<FakeProvider> {
  const FakeFactory({required this.id, this.order = 0});

  @override
  final String id;

  @override
  final int order;

  @override
  FakeProvider create(KaiselSession session) => FakeProvider(session);
}

/// A factory of no SPI Kaisel knows, to prove registration is checked.
class OrphanFactory implements ProviderFactory<FakeProvider> {
  const OrphanFactory();

  @override
  String get id => 'orphan';

  @override
  int get order => 0;

  @override
  FakeProvider create(KaiselSession session) => FakeProvider(session);
}
