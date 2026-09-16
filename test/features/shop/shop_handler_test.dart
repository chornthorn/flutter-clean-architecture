import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/features/shop/domain/entities/cart.dart';
import 'package:flutter_x/features/shop/domain/usecases/add_product_to_cart_command.dart';
import 'package:flutter_x/features/shop/domain/usecases/get_cart_products_query.dart';
import 'package:flutter_x/features/shop/domain/usecases/get_cart_query.dart';
import 'package:flutter_x/features/shop/domain/usecases/get_product_query.dart';
import 'package:flutter_x/features/shop/domain/usecases/get_products_query.dart';
import 'package:mocktail/mocktail.dart';

import 'domain/entities/product_fixture.dart';
import 'domain/repositories/mock_audit_log.dart';
import 'domain/repositories/mock_cart_repository.dart';
import 'domain/repositories/mock_product_repository.dart';
import 'shop_dispatcher_fixture.dart';

void main() {
  group('ShopCqrsModule', () {
    setUpAll(() => registerFallbackValue(const Cart.empty()));

    late MockProductRepository products;

    setUp(() {
      products = MockProductRepository();
      when(
        () => products.allProducts(),
      ).thenAnswer((_) async => const [product]);
      when(
        () => products.productById('sku-42'),
      ).thenAnswer((_) async => product);
    });

    test('should dispatch every query the shop declares', () async {
      final cart = MockCartRepository();
      when(() => cart.cart()).thenAnswer((_) async => const Cart(['sku-42']));

      final dispatcher = shopDispatcher(products, cart: cart);

      expect(await dispatcher.query(const GetProductsQuery()), const [product]);
      expect(await dispatcher.query(const GetProductQuery('sku-42')), product);
      expect(
        await dispatcher.query(const GetCartQuery()),
        const Cart(['sku-42']),
      );
      expect(await dispatcher.query(const GetCartProductsQuery()), const [
        product,
      ]);
    });

    test('should dispatch the command and fan its event out', () async {
      final cart = MockCartRepository();
      when(() => cart.cart()).thenAnswer((_) async => const Cart.empty());
      when(() => cart.save(any())).thenAnswer((_) async {});
      final auditLog = MockAuditLog();
      when(() => auditLog.append(any())).thenAnswer((_) async {});

      final dispatcher = shopDispatcher(
        products,
        cart: cart,
        auditLog: auditLog,
      );

      await dispatcher.command(const AddProductToCartCommand('sku-42'));

      // The audit entry lands only if the event found its handler.
      verify(() => cart.save(const Cart(['sku-42']))).called(1);
      verify(() => auditLog.append('product.added sku-42 items=1')).called(1);
    });
  });
}
