import 'package:flutter/material.dart';
import 'package:kaisel/kaisel.dart';
import 'package:provider/provider.dart';

import '../../../../app/app_route.dart';
import '../../../../core/design_system/app_theme.g.dart';
import '../../../../core/design_system/components/app_buttons.dart';
import '../../../../core/design_system/components/app_notice.dart';
import '../../../../core/design_system/components/app_scaffold.dart';
import '../../shop_module.dart';
import '../view_models/shop_home_view_model.dart';
import '../widgets/cart_button.dart';
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

    return AppScaffold(
      title: const Text('Shop'),
      actions: [
        const CartButton(),
        // The feature's inner navigator has nothing to pop here, so this
        // leaves the feature.
        IconButton(
          onPressed: () => context.router<AppRoute>().pop(),
          icon: const Icon(Icons.close),
          tooltip: 'Exit shop',
        ),
      ],
      body: _buildBody(context, viewModel),
    );
  }

  Widget _buildBody(BuildContext context, ShopHomeViewModel viewModel) {
    final theme = context.theme;

    // Gated on `products == null` so a refresh keeps the current list on screen
    // instead of flashing a spinner.
    if (viewModel.isLoading && viewModel.products == null) {
      return Center(
        child: CircularProgressIndicator(color: theme.colors.brand.primary),
      );
    }

    if (viewModel.error != null) {
      return AppNotice(
        icon: Icons.cloud_off_outlined,
        message: 'Could not load products.',
        isFailure: true,
        action: AppFilledButton(label: 'Try again', onPressed: viewModel.load),
      );
    }

    final products = viewModel.products ?? const [];
    if (products.isEmpty) {
      return const AppNotice(
        icon: Icons.inventory_2_outlined,
        message: 'No products yet.',
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(theme.sizes.padding.md),
      itemCount: products.length,
      separatorBuilder: (context, index) =>
          SizedBox(height: theme.sizes.spacing.sm),
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
