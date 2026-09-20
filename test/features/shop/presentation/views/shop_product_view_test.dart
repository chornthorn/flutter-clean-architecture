import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/shop/domain/entities/cart.dart';
import 'package:flutter_x/features/shop/presentation/view_models/shop_product_view_model.dart';
import 'package:flutter_x/features/shop/presentation/views/shop_product_view.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../app/view_host.dart';
import '../../domain/entities/product_fixture.dart';
import '../../domain/repositories/mock_cart_repository.dart';
import '../../domain/repositories/mock_product_repository.dart';
import '../../shop_dispatcher_fixture.dart';

void main() {
  setUpAll(() => registerFallbackValue(const Cart.empty()));

  group('ShopProductView', () {
    testWidgets('should render the product the view model holds', (
      tester,
    ) async {
      final repository = MockProductRepository();
      when(() => repository.productById('sku-42'))
          .thenAnswer((_) async => product);

      final viewModel = ShopProductViewModel(
        dispatcher: shopDispatcher(repository),
      );
      addTearDown(viewModel.dispose);
      await viewModel.load('sku-42');

      await tester.pumpWidget(
        hostSignalPage(viewModel, const ShopProductView(id: 'sku-42')),
      );

      expect(find.widgetWithText(AppBar, 'sku-42'), findsOneWidget);
      expect(find.text('Espresso cup'), findsOneWidget);
      expect(find.text('12.50'), findsOneWidget);
    });

    testWidgets('should render the not-found state', (tester) async {
      final repository = MockProductRepository();
      when(() => repository.productById('nope')).thenAnswer((_) async => null);

      final viewModel = ShopProductViewModel(
        dispatcher: shopDispatcher(repository),
      );
      addTearDown(viewModel.dispose);
      await viewModel.load('nope');

      await tester.pumpWidget(
        hostSignalPage(viewModel, const ShopProductView(id: 'nope')),
      );

      expect(find.text('Product not found.'), findsOneWidget);
    });

    testWidgets('should count the product in when the button is tapped', (
      tester,
    ) async {
      final repository = MockProductRepository();
      when(() => repository.productById('sku-42'))
          .thenAnswer((_) async => product);

      // Real cart: the count is the query's answer, not the button's.
      final viewModel = ShopProductViewModel(
        dispatcher: shopDispatcher(repository),
      );
      addTearDown(viewModel.dispose);
      await viewModel.load('sku-42');

      await tester.pumpWidget(
        hostSignalPage(viewModel, const ShopProductView(id: 'sku-42')),
      );
      expect(find.text('0 in cart'), findsOneWidget);

      await tester.tap(find.text('Add to cart'));
      await tester.pumpAndSettle();

      expect(find.text('1 in cart'), findsOneWidget);
    });

    testWidgets('should report an add that failed', (tester) async {
      final repository = MockProductRepository();
      when(() => repository.productById('sku-42'))
          .thenAnswer((_) async => product);
      final cart = MockCartRepository();
      when(() => cart.cart()).thenAnswer((_) async => const Cart.empty());
      when(() => cart.save(any())).thenAnswer((_) async => throw Exception());

      final viewModel = ShopProductViewModel(
        dispatcher: shopDispatcher(repository, cart: cart),
      );
      addTearDown(viewModel.dispose);
      await viewModel.load('sku-42');

      await tester.pumpWidget(
        hostSignalPage(viewModel, const ShopProductView(id: 'sku-42')),
      );

      await tester.tap(find.text('Add to cart'));
      await tester.pumpAndSettle();

      // The product stays on screen; only the cart line reports the failure.
      expect(find.text('Could not add to cart.'), findsOneWidget);
      expect(find.text('Espresso cup'), findsOneWidget);
    });
  });
}
