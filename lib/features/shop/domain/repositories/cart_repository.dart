import '../entities/cart.dart';

// The cart's write model; the use case depends on this, not the adapter.
abstract interface class CartRepository {
  // Empty before anything has been added.
  Future<Cart> cart();

  Future<void> save(Cart cart);
}
