import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/design_system/app_theme.g.dart';
import '../../../../core/design_system/components/app_buttons.dart';
import '../../../../core/design_system/components/app_card.dart';
import '../../../../core/design_system/components/app_failure_line.dart';
import '../../../../core/design_system/components/app_notice.dart';
import '../../../../core/design_system/components/app_scaffold.dart';
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

    return AppScaffold(
      title: Text(id),
      actions: const [CartButton()],
      body: _buildBody(context, viewModel),
    );
  }

  Widget _buildBody(BuildContext context, ShopProductViewModel viewModel) {
    final theme = context.theme;

    if (viewModel.isLoading) {
      return Center(
        child: CircularProgressIndicator(color: theme.colors.brand.primary),
      );
    }

    final product = viewModel.product;
    if (product == null) {
      // A failure and a missing id both leave no product; only one is an error,
      // and only one of them is worth asking the far side again.
      if (viewModel.error != null) {
        return AppNotice(
          icon: Icons.cloud_off_outlined,
          message: 'Could not load the product.',
          isFailure: true,
          action: AppFilledButton(
            label: 'Try again',
            onPressed: () => viewModel.load(id),
          ),
        );
      }

      return const AppNotice(
        icon: Icons.search_off_outlined,
        message: 'Product not found.',
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(theme.sizes.padding.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The headline belongs to the page, the way a post's does.
          Text(product.name, style: theme.typography.display.regular),
          SizedBox(height: theme.sizes.spacing.sm),
          Text(product.id, style: theme.typography.label.regular),
          SizedBox(height: theme.sizes.spacing.xl),
          AppCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Price', style: theme.typography.label.regular),
                Text(
                  product.price.toStringAsFixed(2),
                  style: theme.typography.title.semiBold,
                ),
              ],
            ),
          ),
          SizedBox(height: theme.sizes.spacing.md),
          AppFilledButton(
            label: 'Add to cart',
            icon: Icons.add_shopping_cart,
            onPressed: viewModel.addToCart,
          ),
          SizedBox(height: theme.sizes.spacing.md),
          // The product is on screen, so an error here is the add's, not the
          // load's.
          if (viewModel.error != null)
            const AppFailureLine(message: 'Could not add to cart.')
          else
            Text(
              '${viewModel.cartCount} in cart',
              style: theme.typography.label.regular,
            ),
        ],
      ),
    );
  }
}
