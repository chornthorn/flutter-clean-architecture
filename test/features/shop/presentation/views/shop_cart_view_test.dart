import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/shop/domain/entities/cart.dart';
import 'package:flutter_x/features/shop/presentation/view_models/shop_cart_view_model.dart';
import 'package:flutter_x/features/shop/presentation/views/shop_cart_view.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../app/view_host.dart';
import '../../domain/entities/product_fixture.dart';
import '../../domain/repositories/mock_cart_repository.dart';
import '../../domain/repositories/mock_product_repository.dart';
import '../../shop_dispatcher_fixture.dart';

void main() {
  group('ShopCartView', () {
    testWidgets('should render the items and what they add up to', (
      tester,
    ) async {
      final cart = MockCartRepository();
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

      await tester.pumpWidget(hostSignalPage(viewModel, const ShopCartView()));

      expect(find.text('Espresso cup'), findsNWidgets(2));
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('25.00'), findsOneWidget);
    });

    testWidgets('should render the empty state', (tester) async {
      final cart = MockCartRepository();
      when(() => cart.cart()).thenAnswer((_) async => const Cart.empty());

      final viewModel = ShopCartViewModel(
        shopDispatcher(MockProductRepository(), cart: cart),
      );
      addTearDown(viewModel.dispose);
      await viewModel.load();

      await tester.pumpWidget(hostSignalPage(viewModel, const ShopCartView()));

      expect(find.text('Your cart is empty.'), findsOneWidget);
      expect(find.text('Total'), findsNothing);
    });

    testWidgets('should report a cart that could not be read', (tester) async {
      final cart = MockCartRepository();
      when(
        () => cart.cart(),
      ).thenAnswer((_) async => throw Exception('offline'));

      final viewModel = ShopCartViewModel(
        shopDispatcher(MockProductRepository(), cart: cart),
      );
      addTearDown(viewModel.dispose);
      await viewModel.load();

      await tester.pumpWidget(hostSignalPage(viewModel, const ShopCartView()));

      expect(find.text('Could not load the cart.'), findsOneWidget);
    });

    testWidgets('should read the cart again when the failure is retried', (
      tester,
    ) async {
      final cart = MockCartRepository();
      var attempts = 0;
      when(() => cart.cart()).thenAnswer((_) async {
        attempts++;
        // Fails once, then answers, so the retry has something to show.
        if (attempts == 1) throw Exception('offline');
        return const Cart(['sku-42']);
      });
      final products = MockProductRepository();
      when(
        () => products.productById('sku-42'),
      ).thenAnswer((_) async => product);

      final viewModel = ShopCartViewModel(shopDispatcher(products, cart: cart));
      addTearDown(viewModel.dispose);
      await viewModel.load();

      await tester.pumpWidget(hostSignalPage(viewModel, const ShopCartView()));
      expect(find.text('Could not load the cart.'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Could not load the cart.'), findsNothing);
      expect(find.text('Espresso cup'), findsOneWidget);
      expect(find.text('12.50'), findsNWidgets(2));
    });
  });
}
