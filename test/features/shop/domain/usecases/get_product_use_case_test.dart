import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/shop/domain/usecases/get_product_use_case.dart';
import 'package:mocktail/mocktail.dart';

import '../entities/product_fixture.dart';
import '../repositories/mock_product_repository.dart';

void main() {
  group('GetProductUseCase', () {
    test('should return the product for the id it is given', () async {
      final repository = MockProductRepository();
      when(() => repository.productById('sku-42'))
          .thenAnswer((_) async => product);

      final found = await GetProductUseCase(repository)('sku-42');

      expect(found, product);
    });

    test('should resolve an unknown id to null, not a failure', () async {
      final repository = MockProductRepository();
      when(() => repository.productById('no-such-sku'))
          .thenAnswer((_) async => null);

      final found = await GetProductUseCase(repository)('no-such-sku');

      expect(found, isNull);
    });
  });
}
