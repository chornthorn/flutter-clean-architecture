import 'package:flutter/material.dart';

import '../../../../core/design_system/app_theme.g.dart';
import '../../../../core/design_system/components/app_card.dart';
import '../../domain/entities/product.dart';

// One row in the product list. No routing, no data access — the page above
// decides what a tap means.
class ProductTile extends StatelessWidget {
  const ProductTile({super.key, required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: theme.typography.title.regular),
                SizedBox(height: theme.sizes.spacing.sm),
                // The name is what a person calls the product; the id is what
                // the catalog calls it.
                Text(product.id, style: theme.typography.label.regular),
              ],
            ),
          ),
          SizedBox(width: theme.sizes.spacing.md),
          Text(
            product.price.toStringAsFixed(2),
            style: theme.typography.title.regular,
          ),
        ],
      ),
    );
  }
}
