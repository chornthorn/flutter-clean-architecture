// A product in the shop catalog.
//
// Plain Dart: the shape a screen needs, not the shape an API returns — that
// mapping belongs in `infrastructure/`.
class Product {
  const Product({required this.id, required this.name, required this.price});

  final String id;
  final String name;
  final double price;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product &&
          other.id == id &&
          other.name == name &&
          other.price == price;

  @override
  int get hashCode => Object.hash(id, name, price);

  @override
  String toString() => 'Product($id, $name, $price)';
}
