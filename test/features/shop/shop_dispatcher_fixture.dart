import 'package:cqrs/cqrs.dart';
import 'package:flutter_x/features/shop/domain/repositories/audit_log.dart';
import 'package:flutter_x/features/shop/domain/repositories/cart_repository.dart';
import 'package:flutter_x/features/shop/domain/repositories/product_repository.dart';
import 'package:flutter_x/features/shop/domain/usecases/add_product_to_cart_command.dart';
import 'package:flutter_x/features/shop/domain/usecases/get_product_query.dart';
import 'package:flutter_x/features/shop/domain/usecases/get_products_query.dart';
import 'package:flutter_x/features/shop/domain/usecases/product_added_to_cart_event.dart';
import 'package:flutter_x/features/shop/infrastructure/repositories/in_memory_audit_log.dart';
import 'package:flutter_x/features/shop/infrastructure/repositories/in_memory_cart_repository.dart';
import 'package:flutter_x/features/shop/shop_handler.dart';

// A real dispatcher over the shop's generated handler module — the query and
// command paths the container builds at runtime, with the repositories passed in
// instead of resolved. Built from the generated module, so a handler the
// generator misses fails here rather than in the app.
//
// The dispatcher is also the publisher, as in `provider.dart`, so a command's
// event really reaches the event handlers.
CqrsDispatcher shopDispatcher(
  ProductRepository products, {
  CartRepository? cart,
  AuditLog? auditLog,
}) {
  final dispatcher = CqrsDispatcher();
  final cartStore = cart ?? InMemoryCartRepository();
  final log = auditLog ?? InMemoryAuditLog();

  dispatcher.registry.registerModule(
    ShopCqrsModule(
      addProductToCartCommandHandler: () =>
          AddProductToCartCommandHandler(products, cartStore, dispatcher),
      getProductQueryHandler: () => GetProductQueryHandler(products),
      getProductsQueryHandler: () => GetProductsQueryHandler(products),
      productAddedToCartAuditHandler: () => ProductAddedToCartAuditHandler(log),
    ),
  );

  return dispatcher;
}
