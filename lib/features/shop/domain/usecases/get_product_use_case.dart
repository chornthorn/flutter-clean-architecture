import 'package:injectify/injectify.dart';

import '../entities/product.dart';
import '../repositories/product_repository.dart';

/// Reads one product by id.
@Injectable(scope: Scope.factory)
class GetProductUseCase {
  const GetProductUseCase(this._products);

  final ProductRepository _products;

  // An unknown id is a normal outcome, not a failure, so the answer is nullable.
  Future<Product?> call(String id) => _products.productById(id);
}
