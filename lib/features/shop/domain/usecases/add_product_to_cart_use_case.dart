import 'package:cqrs/cqrs.dart';
import 'package:injectify/injectify.dart';

import '../repositories/cart_repository.dart';
import '../repositories/product_repository.dart';
import 'product_added_to_cart_event.dart';

/// Puts one product in the cart.
///
/// The write side. The event carries the new count, so a handler on it need not
/// re-read the cart.
///
/// This is the one place a feature holds a dispatcher, and `publish` is the one
/// call it makes: an event is the message modules send each other, while a read
/// or a write is a use case. See `docs/architecture.md`.
@Injectable(scope: Scope.factory)
class AddProductToCartUseCase {
  const AddProductToCartUseCase(this._products, this._cart, this._dispatcher);

  final ProductRepository _products;
  final CartRepository _cart;
  final CqrsDispatcher _dispatcher;

  Future<void> call(String productId) async {
    final product = await _products.productById(productId);

    // An id that is not in the catalog is bad input, not a cart state.
    if (product == null) {
      throw ArgumentError.value(
        productId,
        'productId',
        'No product with that id',
      );
    }

    final updated = (await _cart.cart()).withProduct(product.id);
    await _cart.save(updated);
    await _dispatcher.publish(
      ProductAddedToCartEvent(product.id, updated.itemCount),
    );
  }
}
