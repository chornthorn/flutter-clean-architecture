import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/shop/domain/usecases/get_product_query.dart';
import 'package:mocktail/mocktail.dart';

import '../entities/product_fixture.dart';
import '../repositories/mock_product_repository.dart';

void main() {
  group('GetProductQueryHandler', () {
    test('should return the product for the id the query carries', () async {
      final repository = MockProductRepository();
      when(() => repository.productById('sku-42'))
          .thenAnswer((_) async => product);

      final found = await GetProductQueryHandler(repository)
          .execute(const GetProductQuery('sku-42'));

      expect(found, product);
    });

    test('should resolve an unknown id to null, not a failure', () async {
      final repository = MockProductRepository();
      when(() => repository.productById('no-such-sku'))
          .thenAnswer((_) async => null);

      final found = await GetProductQueryHandler(repository)
          .execute(const GetProductQuery('no-such-sku'));

      expect(found, isNull);
    });
  });
}
