import '../entities/cart.dart';

// The cart's write model. Declared here so the command handler depends on this
// and not on the adapter that stores it.
abstract interface class CartRepository {
  // Empty before anything has been added.
  Future<Cart> cart();

  Future<void> save(Cart cart);
}
