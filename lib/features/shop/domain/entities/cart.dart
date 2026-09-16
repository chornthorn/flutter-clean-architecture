// The shopper's cart: the product ids they have added, oldest first. One entry
// per add, so the item count is the list length.
//
// Immutable — [withProduct] returns a new cart rather than changing this one.
class Cart {
  const Cart(this.productIds);

  const Cart.empty() : productIds = const [];

  final List<String> productIds;

  int get itemCount => productIds.length;

  Cart withProduct(String productId) => Cart([...productIds, productId]);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Cart && _sameItems(other.productIds, productIds);

  @override
  int get hashCode => Object.hashAll(productIds);

  @override
  String toString() => 'Cart(${productIds.join(', ')})';

  static bool _sameItems(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
