import 'package:flutter/material.dart';
import 'package:kaisel/kaisel.dart';
import 'package:provider/provider.dart';

import '../../../../core/design_system/app_theme.g.dart';
import '../../../../core/design_system/components/app_buttons.dart';
import '../../../../core/design_system/components/app_card.dart';
import '../../../../core/design_system/components/app_notice.dart';
import '../../../../core/design_system/components/app_scaffold.dart';
import '../../shop_module.dart';
import '../view_models/shop_cart_view_model.dart';
import '../widgets/product_tile.dart';

// What is in the cart: one row per add, and what the rows add up to.
class ShopCartView extends StatelessWidget {
  const ShopCartView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<ShopCartViewModel>();

    return AppScaffold(
      title: const Text('Cart'),
      body: _buildBody(context, viewModel),
    );
  }

  Widget _buildBody(BuildContext context, ShopCartViewModel viewModel) {
    final theme = context.theme;

    // Gated on `products == null` so a reload keeps the rows on screen instead
    // of flashing a spinner.
    if (viewModel.isLoading && viewModel.products == null) {
      return Center(
        child: CircularProgressIndicator(color: theme.colors.brand.primary),
      );
    }

    if (viewModel.error != null) {
      return AppNotice(
        icon: Icons.cloud_off_outlined,
        message: 'Could not load the cart.',
        isFailure: true,
        action: AppFilledButton(label: 'Try again', onPressed: viewModel.load),
      );
    }

    final products = viewModel.products ?? const [];
    if (products.isEmpty) {
      return const AppNotice(
        icon: Icons.shopping_cart_outlined,
        message: 'Your cart is empty.',
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.all(theme.sizes.padding.md),
            itemCount: products.length,
            separatorBuilder: (context, index) =>
                SizedBox(height: theme.sizes.spacing.sm),
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
        Padding(
          padding: EdgeInsets.fromLTRB(
            theme.sizes.padding.md,
            0,
            theme.sizes.padding.md,
            theme.sizes.padding.md,
          ),
          child: AppCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total', style: theme.typography.label.regular),
                Text(
                  viewModel.total.toStringAsFixed(2),
                  style: theme.typography.title.semiBold,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
