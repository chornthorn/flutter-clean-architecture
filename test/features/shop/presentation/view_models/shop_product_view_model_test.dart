import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/shop/domain/entities/cart.dart';
import 'package:flutter_x/features/shop/presentation/view_models/shop_product_view_model.dart';
import 'package:mocktail/mocktail.dart';

import '../../domain/entities/product_fixture.dart';
import '../../domain/repositories/mock_cart_repository.dart';
import '../../domain/repositories/mock_product_repository.dart';
import '../../shop_dispatcher_fixture.dart';

void main() {
  // mocktail needs a fallback before `any()` can match a `Cart` argument.
  setUpAll(() => registerFallbackValue(const Cart.empty()));

  group('ShopProductViewModel', () {
    test('should load the product the query returns', () async {
      final repository = MockProductRepository();
      when(
        () => repository.productById('sku-42'),
      ).thenAnswer((_) async => product);

      final viewModel = ShopProductViewModel(shopDispatcher(repository));
      addTearDown(viewModel.dispose);

      await viewModel.load('sku-42');

      expect(viewModel.product, product);
      expect(viewModel.error, isNull);
      expect(viewModel.isLoading, isFalse);
    });

    test(
      'should resolve an unknown id to a null product, not an error',
      () async {
        final repository = MockProductRepository();
        when(
          () => repository.productById('no-such-sku'),
        ).thenAnswer((_) async => null);

        final viewModel = ShopProductViewModel(shopDispatcher(repository));
        addTearDown(viewModel.dispose);

        await viewModel.load('no-such-sku');

        expect(viewModel.product, isNull);
        expect(viewModel.error, isNull);
        expect(viewModel.isLoading, isFalse);
      },
    );

    test('should hold a failure in error instead of throwing', () async {
      final repository = MockProductRepository();
      when(
        () => repository.productById('sku-42'),
      ).thenAnswer((_) async => throw Exception('offline'));

      final viewModel = ShopProductViewModel(shopDispatcher(repository));
      addTearDown(viewModel.dispose);

      await expectLater(viewModel.load('sku-42'), completes);

      expect(viewModel.error, isA<Exception>());
      expect(viewModel.product, isNull);
    });

    test('should read the cart alongside the product', () async {
      final repository = MockProductRepository();
      when(
        () => repository.productById('sku-42'),
      ).thenAnswer((_) async => product);
      final cart = MockCartRepository();
      when(
        () => cart.cart(),
      ).thenAnswer((_) async => const Cart(['sku-99', 'sku-99']));

      final viewModel = ShopProductViewModel(
        shopDispatcher(repository, cart: cart),
      );
      addTearDown(viewModel.dispose);

      await viewModel.load('sku-42');

      expect(viewModel.cartCount, 2);
    });

    test('should send the command and count what the cart holds', () async {
      final repository = MockProductRepository();
      when(
        () => repository.productById('sku-42'),
      ).thenAnswer((_) async => product);

      // Real cart and audit log: the count is read back through the query, so a
      // command that failed to write shows up here as a stale count.
      final viewModel = ShopProductViewModel(shopDispatcher(repository));
      addTearDown(viewModel.dispose);
      await viewModel.load('sku-42');

      await viewModel.addToCart();
      expect(viewModel.cartCount, 1);

      await viewModel.addToCart();
      expect(viewModel.cartCount, 2);

      expect(viewModel.product, product);
      expect(viewModel.error, isNull);
    });

    test('should hold an add failure in error, keeping the product', () async {
      final repository = MockProductRepository();
      when(
        () => repository.productById('sku-42'),
      ).thenAnswer((_) async => product);
      final cart = MockCartRepository();
      when(() => cart.cart()).thenAnswer((_) async => const Cart.empty());
      when(() => cart.save(any())).thenAnswer((_) async => throw Exception());

      final viewModel = ShopProductViewModel(
        shopDispatcher(repository, cart: cart),
      );
      addTearDown(viewModel.dispose);
      await viewModel.load('sku-42');

      await expectLater(viewModel.addToCart(), completes);

      expect(viewModel.error, isA<Exception>());
      expect(viewModel.product, product);
      expect(viewModel.cartCount, 0);
    });
  });
}
