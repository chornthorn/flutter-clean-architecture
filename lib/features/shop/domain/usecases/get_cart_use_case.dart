import 'package:injectify/injectify.dart';

import '../entities/cart.dart';
import '../repositories/cart_repository.dart';

/// Reads the current cart.
@Injectable(scope: Scope.factory)
class GetCartUseCase {
  const GetCartUseCase(this._cart);

  final CartRepository _cart;

  Future<Cart> call() => _cart.cart();
}
