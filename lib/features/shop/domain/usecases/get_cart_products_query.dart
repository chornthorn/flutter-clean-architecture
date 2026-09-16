import 'package:cqrs/cqrs.dart';
import 'package:injectify/injectify.dart';

import '../entities/product.dart';
import '../repositories/cart_repository.dart';
import '../repositories/product_repository.dart';

// The products in the cart, in the order they were added.
class GetCartProductsQuery extends Query<List<Product>> {
  const GetCartProductsQuery();
}

// A read that spans two aggregates: the cart knows ids, the catalog knows
// products, and neither alone answers what is in the cart.
@Injectable(scope: Scope.factory)
class GetCartProductsQueryHandler
    implements QueryHandler<GetCartProductsQuery, List<Product>> {
  const GetCartProductsQueryHandler(this._cart, this._products);

  final CartRepository _cart;
  final ProductRepository _products;

  @override
  Future<List<Product>> execute(GetCartProductsQuery query) async {
    final ids = (await _cart.cart()).productIds;

    // Looked up together rather than one after another. A batch read belongs on
    // `ProductRepository` once an adapter makes one call per id expensive.
    final found = await Future.wait(ids.map(_products.productById));

    // An id the catalog no longer has is dropped, not shown as a gap.
    return [for (final product in found) ?product];
  }
}
