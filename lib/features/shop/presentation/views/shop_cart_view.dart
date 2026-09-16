import 'package:flutter/material.dart';
import 'package:kaisel/kaisel.dart';
import 'package:provider/provider.dart';

import '../../../../core/design_system/app_theme.g.dart';
import '../../shop_module.dart';
import '../view_models/shop_cart_view_model.dart';
import '../widgets/product_tile.dart';

// What is in the cart: one row per add, and what the rows add up to.
class ShopCartView extends StatelessWidget {
  const ShopCartView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ShopCartViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: _buildBody(context, viewModel),
    );
  }

  Widget _buildBody(BuildContext context, ShopCartViewModel viewModel) {
    // Gated on `products == null` so a reload keeps the rows on screen instead
    // of flashing a spinner.
    if (viewModel.isLoading && viewModel.products == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.error != null) {
      return const Center(child: Text('Could not load the cart.'));
    }

    final products = viewModel.products ?? const [];
    if (products.isEmpty) {
      return const Center(child: Text('Your cart is empty.'));
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              // Rows keep the product list's meaning: tap one to open it.
              return ProductTile(
                product: product,
                onTap: () => context.push(ShopProduct(product.id)),
              );
            },
          ),
        ),
        const Divider(),
        Padding(
          padding: EdgeInsets.all(context.theme.sizes.padding.md),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total'),
              Text(viewModel.total.toStringAsFixed(2)),
            ],
          ),
        ),
      ],
    );
  }
}
