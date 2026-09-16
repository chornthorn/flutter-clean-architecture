import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/shop/domain/entities/product.dart';
import 'package:flutter_x/features/shop/presentation/view_models/shop_home_view_model.dart';
import 'package:flutter_x/features/shop/presentation/views/shop_home_view.dart';
import 'package:mocktail/mocktail.dart';

import '../../domain/entities/product_fixture.dart';
import '../../domain/repositories/mock_product_repository.dart';
import '../../shop_dispatcher_fixture.dart';
import 'view_host.dart';

void main() {
  group('ShopHomeView', () {
    testWidgets('should show a spinner while the catalog loads', (
      tester,
    ) async {
      final repository = MockProductRepository();
      when(
        () => repository.allProducts(),
      ).thenAnswer((_) => Completer<List<Product>>().future);
      final viewModel = ShopHomeViewModel(shopDispatcher(repository));
      addTearDown(viewModel.dispose);
      unawaited(viewModel.load());

      await tester.pumpWidget(hostPage(viewModel, const ShopHomeView()));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should rebuild when the view model notifies', (tester) async {
      // Guards `context.watch`: with `read` the page would never leave the
      // spinner, because `read` does not subscribe.
      final completer = Completer<List<Product>>();
      final repository = MockProductRepository();
      when(() => repository.allProducts()).thenAnswer((_) => completer.future);
      final viewModel = ShopHomeViewModel(shopDispatcher(repository));
      addTearDown(viewModel.dispose);
      unawaited(viewModel.load());

      await tester.pumpWidget(hostPage(viewModel, const ShopHomeView()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(const [product]);
      await tester.pumpAndSettle();

      expect(find.text('Espresso cup'), findsOneWidget);
      expect(find.text('12.50'), findsOneWidget);
    });

    testWidgets('should render the error state', (tester) async {
      final repository = MockProductRepository();
      when(
        () => repository.allProducts(),
      ).thenAnswer((_) async => throw Exception('offline'));
      final viewModel = ShopHomeViewModel(shopDispatcher(repository));
      addTearDown(viewModel.dispose);
      await viewModel.load();

      await tester.pumpWidget(hostPage(viewModel, const ShopHomeView()));

      expect(find.text('Could not load products.'), findsOneWidget);
    });
  });
}
