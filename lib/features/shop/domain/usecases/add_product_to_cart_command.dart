import 'package:cqrs/cqrs.dart';
import 'package:injectify/injectify.dart';

import '../repositories/cart_repository.dart';
import '../repositories/product_repository.dart';
import 'product_added_to_cart_event.dart';

// Puts one product in the cart. The subject is named in the message: "add to
// cart" would leave the reader asking what gets added.
class AddProductToCartCommand extends Command<void> {
  const AddProductToCartCommand(this.productId);

  final String productId;
}

// The write side: check the product exists, append it to the cart, then announce
// it. The event carries the new count so handlers need not re-read the cart.
//
// The third dependency is the dispatcher itself — it is the app's publisher, so
// publishing needs no second container binding.
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
