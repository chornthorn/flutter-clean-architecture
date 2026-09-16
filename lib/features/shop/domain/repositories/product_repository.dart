import '../entities/product.dart';

// What the shop needs from its data source, in domain terms.
abstract interface class ProductRepository {
  Future<List<Product>> allProducts();

  // `null` when the catalog has no such product.
  Future<Product?> productById(String id);
}
