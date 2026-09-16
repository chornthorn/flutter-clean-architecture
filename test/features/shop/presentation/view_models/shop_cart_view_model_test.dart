import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/shop/domain/entities/cart.dart';
import 'package:flutter_x/features/shop/presentation/view_models/shop_cart_view_model.dart';
import 'package:mocktail/mocktail.dart';

import '../../domain/entities/product_fixture.dart';
import '../../domain/repositories/mock_cart_repository.dart';
import '../../domain/repositories/mock_product_repository.dart';
import '../../shop_dispatcher_fixture.dart';

void main() {
  group('ShopCartViewModel', () {
    test('should report loading until the cart arrives', () async {
      final cart = MockCartRepository();
      when(() => cart.cart()).thenAnswer((_) async => const Cart(['sku-42']));
      final products = MockProductRepository();
      when(
        () => products.productById('sku-42'),
      ).thenAnswer((_) async => product);

      final viewModel = ShopCartViewModel(shopDispatcher(products, cart: cart));
      addTearDown(viewModel.dispose);

      final load = viewModel.load();

      expect(viewModel.isLoading, isTrue);
      expect(viewModel.products, isNull);

      await load;

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.products, const [product]);
    });

    test('should add the items up without storing a second total', () async {
      final cart = MockCartRepository();
      // The same product added twice: one row per add, both in the total.
      when(
        () => cart.cart(),
      ).thenAnswer((_) async => const Cart(['sku-42', 'sku-42']));
      final products = MockProductRepository();
      when(
        () => products.productById('sku-42'),
      ).thenAnswer((_) async => product);

      final viewModel = ShopCartViewModel(shopDispatcher(products, cart: cart));
      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.products, hasLength(2));
      expect(viewModel.total, product.price * 2);
    });

    test('should resolve an empty cart to no items, not an error', () async {
      final cart = MockCartRepository();
      when(() => cart.cart()).thenAnswer((_) async => const Cart.empty());

      final viewModel = ShopCartViewModel(
        shopDispatcher(MockProductRepository(), cart: cart),
      );
      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.products, isEmpty);
      expect(viewModel.total, 0);
      expect(viewModel.error, isNull);
    });

    test('should hold a failure in error instead of throwing', () async {
      final cart = MockCartRepository();
      when(
        () => cart.cart(),
      ).thenAnswer((_) async => throw Exception('offline'));

      final viewModel = ShopCartViewModel(
        shopDispatcher(MockProductRepository(), cart: cart),
      );
      addTearDown(viewModel.dispose);

      await expectLater(viewModel.load(), completes);

      expect(viewModel.error, isA<Exception>());
      expect(viewModel.products, isNull);
    });
  });
}
