import 'package:flutter_x/features/shop/domain/entities/cart.dart';
import 'package:flutter_x/features/shop/domain/usecases/get_cart_query.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../repositories/mock_cart_repository.dart';

void main() {
  group('GetCartQueryHandler', () {
    test('should return the cart the repository holds', () async {
      final cart = MockCartRepository();
      when(() => cart.cart()).thenAnswer((_) async => const Cart(['sku-42']));

      final read = await GetCartQueryHandler(
        cart,
      ).execute(const GetCartQuery());

      expect(read, const Cart(['sku-42']));
    });

    test('should let a repository failure escape', () async {
      final cart = MockCartRepository();
      when(
        () => cart.cart(),
      ).thenAnswer((_) async => throw Exception('offline'));

      // Holding the failure is the view model's job, not the handler's.
      await expectLater(
        GetCartQueryHandler(cart).execute(const GetCartQuery()),
        throwsException,
      );
    });
  });
}
