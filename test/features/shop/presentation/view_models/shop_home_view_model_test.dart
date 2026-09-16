import 'dart:async';

import 'package:flutter_application_1/features/shop/domain/entities/product.dart';
import 'package:flutter_application_1/features/shop/presentation/view_models/shop_home_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../domain/entities/product_fixture.dart';
import '../../domain/repositories/mock_product_repository.dart';
import '../../shop_dispatcher_fixture.dart';

void main() {
  group('ShopHomeViewModel', () {
    test('should report loading until the catalog arrives', () async {
      final completer = Completer<List<Product>>();
      final repository = MockProductRepository();
      when(() => repository.allProducts()).thenAnswer((_) => completer.future);

      final viewModel = ShopHomeViewModel(shopDispatcher(repository));
      addTearDown(viewModel.dispose);

      final load = viewModel.load();

      expect(viewModel.isLoading, isTrue);
      expect(viewModel.products, isNull);
      expect(viewModel.error, isNull);

      completer.complete(const [product]);
      await load;

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.products, const [product]);
    });

    test('should expose the catalog read through the query', () async {
      final repository = MockProductRepository();
      when(
        () => repository.allProducts(),
      ).thenAnswer((_) async => const [product]);

      final viewModel = ShopHomeViewModel(shopDispatcher(repository));
      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.products, const [product]);
      expect(viewModel.error, isNull);
      expect(viewModel.isLoading, isFalse);
    });

    test('should hold a failure in error instead of throwing', () async {
      final repository = MockProductRepository();
      when(
        () => repository.allProducts(),
      ).thenAnswer((_) async => throw Exception('offline'));

      final viewModel = ShopHomeViewModel(shopDispatcher(repository));
      addTearDown(viewModel.dispose);

      await expectLater(viewModel.load(), completes);

      expect(viewModel.error, isA<Exception>());
      expect(viewModel.products, isNull);
    });

    test('should stay silent when a load outlives its view', () async {
      final completer = Completer<List<Product>>();
      final repository = MockProductRepository();
      when(() => repository.allProducts()).thenAnswer((_) => completer.future);

      final viewModel = ShopHomeViewModel(shopDispatcher(repository));
      var notifications = 0;
      viewModel.addListener(() => notifications++);

      final load = viewModel.load();
      final notifiedBeforeDispose = notifications;

      viewModel.dispose();
      completer.complete(const [product]);

      // An unguarded notifyListeners() would complete this future with
      // "A ChangeNotifier was used after being disposed".
      await expectLater(load, completes);

      expect(notifications, notifiedBeforeDispose);
    });
  });
}
