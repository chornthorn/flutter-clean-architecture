import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/shop/domain/entities/product.dart';

void main() {
  group('Product', () {
    test('should be equal when every field matches', () {
      expect(
        const Product(id: 'sku-42', name: 'Espresso cup', price: 12.5),
        const Product(id: 'sku-42', name: 'Espresso cup', price: 12.5),
      );
    });

    test('should differ when a field differs', () {
      expect(
        const Product(id: 'sku-42', name: 'Espresso cup', price: 12.5),
        isNot(const Product(id: 'sku-99', name: 'Espresso cup', price: 12.5)),
      );
    });
  });
}
