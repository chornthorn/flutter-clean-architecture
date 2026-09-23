import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/shop/domain/entities/cart.dart';
import 'package:flutter_x/features/shop/domain/usecases/get_cart_products_use_case.dart';
import 'package:mocktail/mocktail.dart';

import '../entities/product_fixture.dart';
import '../repositories/mock_cart_repository.dart';
import '../repositories/mock_product_repository.dart';

void main() {
  group('GetCartProductsUseCase', () {
    late MockCartRepository cart;
    late MockProductRepository products;
    late GetCartProductsUseCase getCartProducts;

    setUp(() {
      cart = MockCartRepository();
      products = MockProductRepository();
      getCartProducts = GetCartProductsUseCase(cart, products);
    });

    test(
      'should return the products for the ids in the cart, in order',
      () async {
        when(() => cart.cart()).thenAnswer((_) async => const Cart(['sku-99']));
        when(() => products.productById('sku-99'))
            .thenAnswer((_) async => product);

        final items = await getCartProducts();

        expect(items, const [product]);
      },
    );

    test('should drop an id the catalog no longer has', () async {
      when(() => cart.cart())
          .thenAnswer((_) async => const Cart(['sku-42', 'gone']));
      when(() => products.productById('sku-42'))
          .thenAnswer((_) async => product);
      when(() => products.productById('gone')).thenAnswer((_) async => null);

      final items = await getCartProducts();

      expect(items, const [product]);
    });

    test('should read nothing when the cart is empty', () async {
      when(() => cart.cart()).thenAnswer((_) async => const Cart.empty());

      expect(await getCartProducts(), isEmpty);
      verifyNever(() => products.productById(any()));
    });
  });
}
