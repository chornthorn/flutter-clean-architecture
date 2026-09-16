import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/shop/domain/entities/product.dart';
import 'package:flutter_x/features/shop/presentation/view_models/shop_home_view_model.dart';
import 'package:mocktail/mocktail.dart';
import 'package:signals/signals_flutter.dart';

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

      // The read starts in flight, which is what the page renders first.
      expect(viewModel.products.value.isLoading, isTrue);
      expect(viewModel.products.value.hasValue, isFalse);
      expect(viewModel.products.value.hasError, isFalse);

      completer.complete(const [product]);
      await load;

      expect(
        viewModel.products.value,
        AsyncState<List<Product>>.data(const [product]),
      );
      expect(viewModel.products.value.isLoading, isFalse);
    });

    test('should expose the catalog read through the query', () async {
      final repository = MockProductRepository();
      when(
        () => repository.allProducts(),
      ).thenAnswer((_) async => const [product]);

      final viewModel = ShopHomeViewModel(shopDispatcher(repository));
      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(
        viewModel.products.value,
        AsyncState<List<Product>>.data(const [product]),
      );
      expect(viewModel.products.value.hasError, isFalse);
      expect(viewModel.products.value.isLoading, isFalse);
    });

    test('should hold a failure in error instead of throwing', () async {
      final repository = MockProductRepository();
      when(
        () => repository.allProducts(),
      ).thenAnswer((_) async => throw Exception('offline'));

      final viewModel = ShopHomeViewModel(shopDispatcher(repository));
      addTearDown(viewModel.dispose);

      await expectLater(viewModel.load(), completes);

      expect(viewModel.products.value.hasError, isTrue);
      expect(viewModel.products.value.error, isA<Exception>());
      expect(viewModel.products.value.hasValue, isFalse);
      expect(viewModel.products.value.isLoading, isFalse);
    });

    test('should stay silent when a load outlives its view', () async {
      final completer = Completer<List<Product>>();
      final repository = MockProductRepository();
      when(() => repository.allProducts()).thenAnswer((_) => completer.future);

      final viewModel = ShopHomeViewModel(shopDispatcher(repository));
      // Everything the read pushed, so this can be checked after the signal it
      // pushed to has been disposed with the page.
      final pushed = <AsyncState<List<Product>>>[];
      addTearDown(viewModel.products.subscribe(pushed.add));

      final load = viewModel.load();

      // Navigating away is the provider disposing this view model.
      viewModel.dispose();
      completer.complete(const [product]);

      // An unguarded write would throw `SignalsWriteAfterDisposeError`, which
      // would complete this future with it.
      await expectLater(load, completes);

      // A read nobody is watching is not a result, and there is nobody left to
      // tell: the only state it ever pushed is the loading state it started in.
      expect(pushed, isNotEmpty);
      expect(pushed.every((state) => state.isLoading), isTrue);
    });
  });
}
