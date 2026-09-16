import 'package:cqrs/cqrs.dart';
import 'package:injectify/injectify.dart';

import '../repositories/cart_repository.dart';
import '../repositories/product_repository.dart';
import 'product_added_to_cart_event.dart';

// Puts one product in the cart.
class AddProductToCartCommand extends Command<void> {
  const AddProductToCartCommand(this.productId);

  final String productId;
}

// The write side. The event carries the new count, so a handler on it need not
// re-read the cart.
@Injectable(scope: Scope.factory)
class AddProductToCartCommandHandler
    implements CommandHandler<AddProductToCartCommand, void> {
  const AddProductToCartCommandHandler(
    this._products,
    this._cart,
    this._dispatcher,
  );

  final ProductRepository _products;
  final CartRepository _cart;
  final CqrsDispatcher _dispatcher;

  @override
  Future<void> execute(AddProductToCartCommand command) async {
    final product = await _products.productById(command.productId);

    // An id that is not in the catalog is bad input, not a cart state.
    if (product == null) {
      throw ArgumentError.value(
        command.productId,
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
