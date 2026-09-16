import 'package:flutter_application_1/features/shop/presentation/view_models/shop_product_view_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../domain/entities/product_fixture.dart';
import '../../domain/repositories/mock_product_repository.dart';
import '../../shop_dispatcher_fixture.dart';

void main() {
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
  });
}
