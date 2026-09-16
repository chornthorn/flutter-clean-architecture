import 'package:flutter_application_1/app/app.dart';
import 'package:flutter_application_1/features/shop/domain/repositories/product_repository.dart';
import 'package:flutter_application_1/provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'domain/entities/product_fixture.dart';
import 'domain/repositories/mock_product_repository.dart';

void main() {
  late MockProductRepository repository;

  setUp(() async {
    await getIt.reset();
    await configureDependencies();

    // Swap the adapter for a mock, leaving the domain contract intact.
    repository = MockProductRepository();
    when(
      () => repository.allProducts(),
    ).thenAnswer((_) async => const [product]);
    when(
      () => repository.productById('sku-42'),
    ).thenAnswer((_) async => product);

    await getIt.unregister<ProductRepository>();
    getIt.registerLazySingleton<ProductRepository>(() => repository);
  });

  // `verify` replaces a hand-rolled call counter: a second read would mean a
  // navigation rebuild re-created the list view model.
  testWidgets('should load the catalog once per mount, not per rebuild', (
    tester,
  ) async {
    await tester.pumpWidget(const KaiselApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open shop'));
    await tester.pumpAndSettle();

    // Both of these rebuild the list route while it stays mounted.
    await tester.tap(find.text('Espresso cup'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Espresso cup'), findsWidgets);

    // `verify` consumes the calls it matches, so this is asserted once, at the
    // end — a second call anywhere in the flow fails here.
    verify(() => repository.allProducts()).called(1);
  });
}
