import 'package:flutter/material.dart';

import '../../domain/entities/product.dart';

// One row in the product list. No routing, no data access — the page above
// decides what a tap means.
class ProductTile extends StatelessWidget {
  const ProductTile({super.key, required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(product.name),
      subtitle: Text(product.id),
      trailing: Text(product.price.toStringAsFixed(2)),
      onTap: onTap,
    );
  }
}
