import 'package:cqrs/cqrs.dart';
import 'package:injectify/injectify.dart';

import '../entities/cart.dart';
import '../repositories/cart_repository.dart';

// Reads the current cart.
class GetCartQuery extends Query<Cart> {
  const GetCartQuery();
}

@Injectable(scope: Scope.factory)
class GetCartQueryHandler implements QueryHandler<GetCartQuery, Cart> {
  const GetCartQueryHandler(this._cart);

  final CartRepository _cart;

  @override
  Future<Cart> execute(GetCartQuery query) => _cart.cart();
}
