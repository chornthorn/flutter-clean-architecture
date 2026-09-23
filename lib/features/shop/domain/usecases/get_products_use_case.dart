import 'package:injectify/injectify.dart';

import '../entities/product.dart';
import '../repositories/product_repository.dart';

/// Lists the shop catalog.
@Injectable(scope: Scope.factory)
class GetProductsUseCase {
  const GetProductsUseCase(this._products);

  final ProductRepository _products;

  Future<List<Product>> call() => _products.allProducts();
}
