import 'package:cqrs/cqrs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/app/app.dart';
import 'package:flutter_x/features/shop/domain/repositories/audit_log.dart';
import 'package:flutter_x/features/shop/domain/repositories/product_repository.dart';
import 'package:flutter_x/features/shop/domain/usecases/add_product_to_cart_command.dart';
import 'package:flutter_x/features/shop/domain/usecases/get_cart_query.dart';
import 'package:flutter_x/provider.dart';
import 'package:injectify/injectify.dart';
import 'package:mocktail/mocktail.dart';

import 'domain/entities/product_fixture.dart';
import 'domain/repositories/mock_product_repository.dart';

void main() {
  late MockProductRepository repository;

  setUp(() async {
    await getIt.reset();
    await configureDependencies(environment: Environment.test);

    repository = MockProductRepository();
    when(() => repository.allProducts())
        .thenAnswer((_) async => const [product]);
    when(() => repository.productById('sku-42'))
        .thenAnswer((_) async => product);

    await getIt.unregister<ProductRepository>();
    getIt.registerLazySingleton<ProductRepository>(() => repository);
  });

  // Nothing else proves the container can resolve the write path end to end.
  test('should resolve the command path and its event handler', () async {
    final dispatcher = getIt<CqrsDispatcher>();

    await dispatcher.command(const AddProductToCartCommand('sku-42'));

    // Read back through the query, so this covers the cart handler's wiring too.
    expect((await dispatcher.query(const GetCartQuery())).productIds, [
      'sku-42',
    ]);
    expect(await getIt<AuditLog>().entries(), ['product.added sku-42 items=1']);
  });

  // A second read would mean a navigation rebuild re-created the list view model.
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

    verify(() => repository.allProducts()).called(1);
  });
}
