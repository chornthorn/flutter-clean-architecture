import 'package:injectify/injectify.dart';

import '../../domain/entities/product.dart';
import '../../domain/repositories/product_repository.dart';

// A stand-in catalog. Bound to the domain contract, so nothing names this class
// directly — a REST implementation bound to the same contract replaces it
// without touching any other file.
@Injectable(as: ProductRepository, scope: Scope.lazySingleton)
class InMemoryProductRepository implements ProductRepository {
  const InMemoryProductRepository();

  static const _catalog = <Product>[
    Product(id: 'sku-42', name: 'Espresso cup', price: 12.5),
    Product(id: 'sku-99', name: 'Pour-over kettle', price: 48),
  ];

  @override
  Future<List<Product>> allProducts() async => _catalog;

  @override
  Future<Product?> productById(String id) async {
    for (final product in _catalog) {
      if (product.id == id) return product;
    }
    return null;
  }
}
