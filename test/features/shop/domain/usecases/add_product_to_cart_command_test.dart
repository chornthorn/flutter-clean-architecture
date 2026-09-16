import 'package:cqrs/cqrs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/shop/domain/entities/cart.dart';
import 'package:flutter_x/features/shop/domain/usecases/add_product_to_cart_command.dart';
import 'package:flutter_x/features/shop/domain/usecases/product_added_to_cart_event.dart';
import 'package:mocktail/mocktail.dart';

import '../entities/product_fixture.dart';
import '../repositories/mock_audit_log.dart';
import '../repositories/mock_cart_repository.dart';
import '../repositories/mock_product_repository.dart';

void main() {
  group('AddProductToCartCommandHandler', () {
    setUpAll(() => registerFallbackValue(const Cart.empty()));

    late MockProductRepository products;
    late MockCartRepository cart;
    late MockAuditLog auditLog;
    late AddProductToCartCommandHandler handler;

    setUp(() {
      products = MockProductRepository();
      cart = MockCartRepository();
      when(() => cart.save(any())).thenAnswer((_) async {});
      auditLog = MockAuditLog();
      when(() => auditLog.append(any())).thenAnswer((_) async {});

      final dispatcher = CqrsDispatcher()
        ..registry.registerEvent<ProductAddedToCartEvent>(
          () => ProductAddedToCartAuditHandler(auditLog),
        );

      handler = AddProductToCartCommandHandler(products, cart, dispatcher);
    });

    test('should append the product and announce the new count', () async {
      when(
        () => products.productById('sku-42'),
      ).thenAnswer((_) async => product);
      when(() => cart.cart()).thenAnswer((_) async => const Cart(['sku-99']));

      await handler.execute(const AddProductToCartCommand('sku-42'));

      verify(() => cart.save(const Cart(['sku-99', 'sku-42']))).called(1);
      // The count is the cart's new size, not the size before the add.
      verify(() => auditLog.append('product.added sku-42 items=2')).called(1);
    });

    test('should reject a product that is not in the catalog', () async {
      when(() => products.productById('nope')).thenAnswer((_) async => null);

      await expectLater(
        handler.execute(const AddProductToCartCommand('nope')),
        throwsArgumentError,
      );

      verifyNever(() => cart.save(any()));
      verifyNever(() => auditLog.append(any()));
    });
  });
}
