import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/shop/infrastructure/repositories/in_memory_product_repository.dart';

void main() {
  const repository = InMemoryProductRepository();

  group('InMemoryProductRepository', () {
    test('should return the whole catalog', () async {
      expect(await repository.allProducts(), isNotEmpty);
    });

    test('should find a product by id', () async {
      final product = await repository.productById('sku-42');

      expect(product?.name, 'Espresso cup');
    });

    test('should return null for an id the catalog does not have', () async {
      expect(await repository.productById('no-such-sku'), isNull);
    });
  });
}
