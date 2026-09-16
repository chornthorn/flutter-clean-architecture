import 'package:flutter/material.dart';
import 'package:kaisel/kaisel.dart';
import 'package:provider/provider.dart';

import '../../../../app/app_route.dart';
import '../../shop_module.dart';
import '../view_models/shop_home_view_model.dart';
import '../widgets/product_tile.dart';

// The feature's list screen.
//
// Reads its view model from the provider above it — `watch`, so the page
// rebuilds when the view model notifies.
class ShopHomeView extends StatelessWidget {
  const ShopHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ShopHomeViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop'),
        actions: [
          // The feature's inner navigator has nothing to pop here, so this
          // leaves the feature.
          IconButton(
            onPressed: () => context.router<AppRoute>().pop(),
            icon: const Icon(Icons.close),
            tooltip: 'Exit shop',
          ),
        ],
      ),
      body: _buildBody(context, viewModel),
    );
  }

  Widget _buildBody(BuildContext context, ShopHomeViewModel viewModel) {
    // Gated on `products == null` so a refresh keeps the current list on screen
    // instead of flashing a spinner.
    if (viewModel.isLoading && viewModel.products == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.error != null) {
      return const Center(child: Text('Could not load products.'));
    }

    final products = viewModel.products ?? const [];
    return ListView.builder(
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return ProductTile(
          product: product,
          // `ShopProduct` belongs to `ShopRoute`, so this pushes inside the
          // feature rather than on the host stack.
          onTap: () => context.push(ShopProduct(product.id)),
        );
      },
    );
  }
}
