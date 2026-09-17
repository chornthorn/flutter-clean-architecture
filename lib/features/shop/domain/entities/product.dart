import 'package:equatable/equatable.dart';

// A product in the shop catalog.
class Product extends Equatable {
  const Product({required this.id, required this.name, required this.price});

  final String id;
  final String name;
  final double price;

  @override
  List<Object?> get props => [id, name, price];

  @override
  String toString() => 'Product($id, $name, $price)';
}
