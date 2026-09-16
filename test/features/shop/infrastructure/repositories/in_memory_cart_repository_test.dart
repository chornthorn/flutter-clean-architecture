import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/shop/domain/entities/cart.dart';
import 'package:flutter_x/features/shop/infrastructure/repositories/in_memory_cart_repository.dart';

void main() {
  group('InMemoryCartRepository', () {
    test('should start empty', () async {
      expect(await InMemoryCartRepository().cart(), const Cart.empty());
    });

    test('should return the cart it was given', () async {
      final repository = InMemoryCartRepository();

      await repository.save(const Cart(['sku-42']));

      expect(await repository.cart(), const Cart(['sku-42']));
    });
  });
}
