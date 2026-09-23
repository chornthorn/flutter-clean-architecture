import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/shop/domain/entities/product.dart';
import 'package:flutter_x/features/shop/presentation/views/shop_home_view.dart';
import 'package:flutter_x/features/shop/presentation/widgets/product_tile.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../app/view_host.dart';
import '../../domain/entities/product_fixture.dart';
import '../../domain/repositories/mock_product_repository.dart';
import '../../shop_view_model_fixture.dart';

void main() {
  group('ShopHomeView', () {
    testWidgets('should show a spinner while the catalog loads', (
      tester,
    ) async {
      final repository = MockProductRepository();
      when(() => repository.allProducts())
          .thenAnswer((_) => Completer<List<Product>>().future);
      final viewModel = shopHomeViewModel(repository);
      addTearDown(viewModel.dispose);
      unawaited(viewModel.load());

      await tester.pumpWidget(hostSignalPage(viewModel, const ShopHomeView()));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should rebuild when the read settles', (tester) async {
      // Guards the `SignalBuilder`: without it the page stays on the spinner.
      final completer = Completer<List<Product>>();
      final repository = MockProductRepository();
      when(() => repository.allProducts()).thenAnswer((_) => completer.future);
      final viewModel = shopHomeViewModel(repository);
      addTearDown(viewModel.dispose);
      unawaited(viewModel.load());

      await tester.pumpWidget(hostSignalPage(viewModel, const ShopHomeView()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(const [product]);
      await tester.pumpAndSettle();

      expect(find.text('Espresso cup'), findsOneWidget);
      expect(find.text('12.50'), findsOneWidget);
    });

    testWidgets('should render the error state', (tester) async {
      final repository = MockProductRepository();
      when(() => repository.allProducts())
          .thenAnswer((_) async => throw Exception('offline'));
      final viewModel = shopHomeViewModel(repository);
      addTearDown(viewModel.dispose);
      await viewModel.load();

      await tester.pumpWidget(hostSignalPage(viewModel, const ShopHomeView()));

      expect(find.text('Could not load products.'), findsOneWidget);
    });

    testWidgets('should say so when the catalog is empty', (tester) async {
      final repository = MockProductRepository();
      when(() => repository.allProducts()).thenAnswer((_) async => const []);
      final viewModel = shopHomeViewModel(repository);
      addTearDown(viewModel.dispose);
      await viewModel.load();

      await tester.pumpWidget(hostSignalPage(viewModel, const ShopHomeView()));

      expect(find.text('No products yet.'), findsOneWidget);
      expect(find.byType(ProductTile), findsNothing);
    });

    testWidgets('should load again when the failure is retried', (
      tester,
    ) async {
      final repository = MockProductRepository();
      var attempts = 0;
      when(() => repository.allProducts()).thenAnswer((_) async {
        attempts++;
        // Fails once, then answers, so the retry has something to show.
        if (attempts == 1) throw Exception('offline');
        return const [product];
      });
      final viewModel = shopHomeViewModel(repository);
      addTearDown(viewModel.dispose);
      await viewModel.load();

      await tester.pumpWidget(hostSignalPage(viewModel, const ShopHomeView()));
      expect(find.text('Could not load products.'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Could not load products.'), findsNothing);
      expect(find.text('Espresso cup'), findsOneWidget);
    });
  });
}
