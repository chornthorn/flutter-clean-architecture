import 'package:equatable/equatable.dart';

// The shopper's cart: the ids they added, oldest first, one entry per add.
class Cart extends Equatable {
  const Cart(this.productIds);

  const Cart.empty() : productIds = const [];

  final List<String> productIds;

  int get itemCount => productIds.length;

  Cart withProduct(String productId) => Cart([...productIds, productId]);

  @override
  List<Object?> get props => [productIds];

  @override
  String toString() => 'Cart(${productIds.join(', ')})';
}
