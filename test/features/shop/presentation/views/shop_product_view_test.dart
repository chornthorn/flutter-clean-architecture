import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/shop/presentation/view_models/shop_product_view_model.dart';
import 'package:flutter_x/features/shop/presentation/views/shop_product_view.dart';
import 'package:mocktail/mocktail.dart';

import '../../domain/entities/product_fixture.dart';
import '../../domain/repositories/mock_product_repository.dart';
import '../../shop_dispatcher_fixture.dart';
import 'view_host.dart';

void main() {
  group('ShopProductView', () {
    testWidgets('should render the product the view model holds', (
      tester,
    ) async {
      final repository = MockProductRepository();
      when(
        () => repository.productById('sku-42'),
      ).thenAnswer((_) async => product);

      final viewModel = ShopProductViewModel(shopDispatcher(repository));
      addTearDown(viewModel.dispose);
      await viewModel.load('sku-42');

      await tester.pumpWidget(
        hostPage(viewModel, const ShopProductView(id: 'sku-42')),
      );

      expect(find.widgetWithText(AppBar, 'sku-42'), findsOneWidget);
      expect(find.text('Espresso cup'), findsOneWidget);
      expect(find.text('12.50'), findsOneWidget);
    });

    testWidgets('should render the not-found state', (tester) async {
      final repository = MockProductRepository();
      when(() => repository.productById('nope')).thenAnswer((_) async => null);

      final viewModel = ShopProductViewModel(shopDispatcher(repository));
      addTearDown(viewModel.dispose);
      await viewModel.load('nope');

      await tester.pumpWidget(
        hostPage(viewModel, const ShopProductView(id: 'nope')),
      );

      expect(find.text('Product not found.'), findsOneWidget);
    });
  });
}
