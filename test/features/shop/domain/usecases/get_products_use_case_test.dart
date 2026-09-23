import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/shop/domain/usecases/get_products_use_case.dart';
import 'package:mocktail/mocktail.dart';

import '../entities/product_fixture.dart';
import '../repositories/mock_product_repository.dart';

void main() {
  group('GetProductsUseCase', () {
    test('should return the catalog the repository provides', () async {
      final repository = MockProductRepository();
      when(() => repository.allProducts())
          .thenAnswer((_) async => const [product]);

      final products = await GetProductsUseCase(repository)();

      expect(products, const [product]);
    });

    test('should let a repository failure escape', () async {
      final repository = MockProductRepository();
      when(() => repository.allProducts())
          .thenAnswer((_) async => throw Exception('offline'));

      // Holding the failure is the view model's job, not the use case's.
      await expectLater(GetProductsUseCase(repository)(), throwsException);
    });
  });
}
