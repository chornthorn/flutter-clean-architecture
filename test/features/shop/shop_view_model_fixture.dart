import 'package:cqrs/cqrs.dart';
import 'package:flutter_x/features/shop/domain/repositories/audit_log.dart';
import 'package:flutter_x/features/shop/domain/repositories/cart_repository.dart';
import 'package:flutter_x/features/shop/domain/repositories/product_repository.dart';
import 'package:flutter_x/features/shop/domain/usecases/add_product_to_cart_use_case.dart';
import 'package:flutter_x/features/shop/domain/usecases/get_cart_products_use_case.dart';
import 'package:flutter_x/features/shop/domain/usecases/get_cart_use_case.dart';
import 'package:flutter_x/features/shop/domain/usecases/get_product_use_case.dart';
import 'package:flutter_x/features/shop/domain/usecases/get_products_use_case.dart';
import 'package:flutter_x/features/shop/domain/usecases/product_added_to_cart_event.dart';
import 'package:flutter_x/features/shop/infrastructure/repositories/in_memory_audit_log.dart';
import 'package:flutter_x/features/shop/infrastructure/repositories/in_memory_cart_repository.dart';
import 'package:flutter_x/features/shop/presentation/view_models/shop_cart_view_model.dart';
import 'package:flutter_x/features/shop/presentation/view_models/shop_home_view_model.dart';
import 'package:flutter_x/features/shop/presentation/view_models/shop_product_view_model.dart';

// What the container wires up for the three shop screens: the screen's use cases
// over whichever stores a test hands in. The view model is built directly, so a
// test exercises the same graph the container does without reaching for it.

/// The dispatcher the write path publishes its event through, with the audit
/// reaction registered — the one `cqrs` hop the shop still makes.
CqrsDispatcher shopEventDispatcher([AuditLog? auditLog]) => CqrsDispatcher()
  ..registry.registerEvent<ProductAddedToCartEvent>(
    () => ProductAddedToCartAuditHandler(auditLog ?? InMemoryAuditLog()),
  );

ShopHomeViewModel shopHomeViewModel(ProductRepository products) =>
    ShopHomeViewModel(getProducts: GetProductsUseCase(products));

ShopCartViewModel shopCartViewModel(
  ProductRepository products, {
  CartRepository? cart,
}) => ShopCartViewModel(
  getCartProducts: GetCartProductsUseCase(
    cart ?? InMemoryCartRepository(),
    products,
  ),
);

ShopProductViewModel shopProductViewModel(
  ProductRepository products, {
  CartRepository? cart,
  AuditLog? auditLog,
}) {
  final cartStore = cart ?? InMemoryCartRepository();
  return ShopProductViewModel(
    getProduct: GetProductUseCase(products),
    getCart: GetCartUseCase(cartStore),
    addProductToCart: AddProductToCartUseCase(
      products,
      cartStore,
      shopEventDispatcher(auditLog),
    ),
  );
}
