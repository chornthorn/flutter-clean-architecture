import 'package:cqrs/cqrs.dart';
import 'package:flutter_x/features/shop/domain/repositories/audit_log.dart';
import 'package:flutter_x/features/shop/domain/repositories/cart_repository.dart';
import 'package:flutter_x/features/shop/domain/repositories/product_repository.dart';
import 'package:flutter_x/features/shop/domain/usecases/add_product_to_cart_command.dart';
import 'package:flutter_x/features/shop/domain/usecases/get_cart_products_query.dart';
import 'package:flutter_x/features/shop/domain/usecases/get_cart_query.dart';
import 'package:flutter_x/features/shop/domain/usecases/get_product_query.dart';
import 'package:flutter_x/features/shop/domain/usecases/get_products_query.dart';
import 'package:flutter_x/features/shop/domain/usecases/product_added_to_cart_event.dart';
import 'package:flutter_x/features/shop/infrastructure/repositories/in_memory_audit_log.dart';
import 'package:flutter_x/features/shop/infrastructure/repositories/in_memory_cart_repository.dart';
import 'package:flutter_x/features/shop/shop_handler.dart';

// A real dispatcher over the shop's generated handler module.
// Returns a `TestCqrsDispatcher` to support stub overrides and dispatch tracking in tests.
TestCqrsDispatcher shopDispatcher(
  ProductRepository products, {
  CartRepository? cart,
  AuditLog? auditLog,
}) {
  final dispatcher = TestCqrsDispatcher();
  final cartStore = cart ?? InMemoryCartRepository();
  final log = auditLog ?? InMemoryAuditLog();

  dispatcher.registry.registerModule(
    ShopCqrsModule(
      addProductToCartCommandHandler: () =>
          AddProductToCartCommandHandler(products, cartStore, dispatcher),
      getCartProductsQueryHandler: () =>
          GetCartProductsQueryHandler(cartStore, products),
      getCartQueryHandler: () => GetCartQueryHandler(cartStore),
      getProductQueryHandler: () => GetProductQueryHandler(products),
      getProductsQueryHandler: () => GetProductsQueryHandler(products),
      productAddedToCartAuditHandler: () =>
          ProductAddedToCartAuditHandler(log),
    ),
  );

  return dispatcher;
}
