import 'package:cqrs/cqrs.dart';
import 'package:injectify/injectify.dart';

import '../entities/product.dart';
import '../repositories/product_repository.dart';

// Lists the shop catalog.
class GetProductsQuery extends Query<List<Product>> {
  const GetProductsQuery();
}

@Injectable(scope: Scope.factory)
class GetProductsQueryHandler
    implements QueryHandler<GetProductsQuery, List<Product>> {
  const GetProductsQueryHandler(this._repository);

  final ProductRepository _repository;

  @override
  Future<List<Product>> execute(GetProductsQuery query) =>
      _repository.allProducts();
}
