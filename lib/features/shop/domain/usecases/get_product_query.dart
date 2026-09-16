import 'package:cqrs/cqrs.dart';
import 'package:injectify/injectify.dart';

import '../entities/product.dart';
import '../repositories/product_repository.dart';

// Reads one product by id. An unknown id is a normal outcome, not a failure.
class GetProductQuery extends Query<Product?> {
  const GetProductQuery(this.id);

  final String id;
}

@Injectable(scope: Scope.factory)
class GetProductQueryHandler
    implements QueryHandler<GetProductQuery, Product?> {
  const GetProductQueryHandler(this._repository);

  final ProductRepository _repository;

  @override
  Future<Product?> execute(GetProductQuery query) =>
      _repository.productById(query.id);
}
