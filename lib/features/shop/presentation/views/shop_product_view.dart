import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_models/shop_product_view_model.dart';
import '../widgets/cart_button.dart';

// One product, looked up by the id carried on `ShopProduct`.
//
// The page requires the id rather than reading it back off the view model, so
// which product this screen shows is visible from its constructor.
class ShopProductView extends StatelessWidget {
  const ShopProductView({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ShopProductViewModel>();

    return Scaffold(
      appBar: AppBar(title: Text(id), actions: const [CartButton()]),
      body: _buildBody(context, viewModel),
    );
  }

  Widget _buildBody(BuildContext context, ShopProductViewModel viewModel) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final product = viewModel.product;
    if (product == null) {
      // A failure and a missing id both leave no product; only one is an error.
      return Center(
        child: Text(
          viewModel.error == null
              ? 'Product not found.'
              : 'Could not load the product.',
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(product.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(product.price.toStringAsFixed(2)),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: viewModel.addToCart,
            icon: const Icon(Icons.add_shopping_cart),
            label: const Text('Add to cart'),
          ),
          const SizedBox(height: 8),
          // The product is on screen, so an error here is the add's, not the
          // load's.
          Text(
            viewModel.error == null
                ? '${viewModel.cartCount} in cart'
                : 'Could not add to cart.',
          ),
        ],
      ),
    );
  }
}
