import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/shop/domain/entities/cart.dart';

void main() {
  group('Cart', () {
    test('should be empty when nothing has been added', () {
      expect(const Cart.empty().itemCount, 0);
    });

    test('should append a product without changing the cart it came from', () {
      const original = Cart(['sku-42']);

      final updated = original.withProduct('sku-99');

      expect(updated.productIds, ['sku-42', 'sku-99']);
      expect(original.productIds, ['sku-42']);
    });

    test('should count one item per add', () {
      expect(const Cart(['sku-42', 'sku-42']).itemCount, 2);
    });

    test('should be equal when the items match in order', () {
      expect(const Cart(['sku-42']), const Cart(['sku-42']));
      expect(const Cart(['sku-42']), isNot(const Cart(['sku-99'])));
      // The list comparison is hand-rolled, so the length mismatch is its own
      // case: a loop over the shorter list would call these equal.
      expect(const Cart(['sku-42']), isNot(const Cart(['sku-42', 'sku-99'])));
    });
  });
}
