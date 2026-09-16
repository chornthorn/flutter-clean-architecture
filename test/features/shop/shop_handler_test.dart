import 'package:flutter_application_1/features/shop/domain/usecases/get_product_query.dart';
import 'package:flutter_application_1/features/shop/domain/usecases/get_products_query.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'domain/entities/product_fixture.dart';
import 'domain/repositories/mock_product_repository.dart';
import 'shop_dispatcher_fixture.dart';

void main() {
  // The generated module is the only thing binding a query to its handler. A
  // query it fails to register throws HandlerNotFoundException at dispatch.
  test('should dispatch every query the shop declares', () async {
    final repository = MockProductRepository();
    when(
      () => repository.allProducts(),
    ).thenAnswer((_) async => const [product]);
    when(
      () => repository.productById('sku-42'),
    ).thenAnswer((_) async => product);

    final dispatcher = shopDispatcher(repository);

    expect(await dispatcher.query(const GetProductsQuery()), const [product]);
    expect(await dispatcher.query(const GetProductQuery('sku-42')), product);
  });
}
