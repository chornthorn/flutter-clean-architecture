import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../view_models/shop_product_view_model.dart';

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
      appBar: AppBar(title: Text(id)),
      body: _buildBody(context, viewModel),
    );
  }

  Widget _buildBody(BuildContext context, ShopProductViewModel viewModel) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.error != null) {
      return const Center(child: Text('Could not load the product.'));
    }

    final product = viewModel.product;
    if (product == null) {
      return const Center(child: Text('Product not found.'));
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(product.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(product.price.toStringAsFixed(2)),
        ],
      ),
    );
  }
}
