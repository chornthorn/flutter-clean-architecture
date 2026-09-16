import 'package:injectify/injectify.dart';

import '../../domain/entities/cart.dart';
import '../../domain/repositories/cart_repository.dart';

// Holds the cart for as long as the app runs. A persisted replacement binds to
// the same contract.
@Injectable(as: CartRepository, scope: Scope.lazySingleton)
class InMemoryCartRepository implements CartRepository {
  Cart _cart = const Cart.empty();

  @override
  Future<Cart> cart() async => _cart;

  @override
  Future<void> save(Cart cart) async => _cart = cart;
}
