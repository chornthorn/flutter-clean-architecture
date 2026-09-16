import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/shop/domain/entities/cart.dart';
import 'package:flutter_x/features/shop/domain/entities/product.dart';
import 'package:flutter_x/features/shop/presentation/view_models/shop_product_view_model.dart';
import 'package:mocktail/mocktail.dart';
import 'package:signals/signals_flutter.dart';

import '../../domain/entities/product_fixture.dart';
import '../../domain/repositories/mock_cart_repository.dart';
import '../../domain/repositories/mock_product_repository.dart';
import '../../shop_dispatcher_fixture.dart';

void main() {
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

      expect(viewModel.product.value, AsyncState<Product?>.data(product));
      expect(viewModel.product.value.hasError, isFalse);
      expect(viewModel.product.value.isLoading, isFalse);
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

        // A null product is a value: the page tells it from a failure by the state.
        expect(viewModel.product.value, AsyncState<Product?>.data(null));
        expect(viewModel.product.value.hasError, isFalse);
        expect(viewModel.product.value.isLoading, isFalse);
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

      expect(viewModel.product.value.hasError, isTrue);
      expect(viewModel.product.value.hasValue, isFalse);
    });

    test(
      'should start the add settled, so the page does not read it in flight',
      () {
        final viewModel = ShopProductViewModel(
          shopDispatcher(MockProductRepository()),
        );
        addTearDown(viewModel.dispose);

        expect(viewModel.add.value.isLoading, isFalse);
        // The read is the one that starts in flight: it is what the page renders
        // first.
        expect(viewModel.product.value.isLoading, isTrue);
      },
    );

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

      expect(viewModel.cartCount.value, 2);
    });

    test('should send the command and count what the cart holds', () async {
      final repository = MockProductRepository();
      when(
        () => repository.productById('sku-42'),
      ).thenAnswer((_) async => product);

      // Real cart: the count is read back, so a write that failed shows as stale.
      final viewModel = ShopProductViewModel(shopDispatcher(repository));
      addTearDown(viewModel.dispose);
      await viewModel.load('sku-42');

      await viewModel.addToCart();
      expect(viewModel.cartCount.value, 1);

      await viewModel.addToCart();
      expect(viewModel.cartCount.value, 2);

      expect(viewModel.product.value.value, product);
      expect(viewModel.add.value.hasError, isFalse);
      expect(viewModel.add.value.isLoading, isFalse);
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

      expect(viewModel.add.value.hasError, isTrue);
      expect(viewModel.cartCount.value, 0);
      // The read is untouched: the use case that failed is the add, not the read.
      expect(viewModel.product.value.value, product);
      expect(viewModel.product.value.hasError, isFalse);
    });
  });
}
