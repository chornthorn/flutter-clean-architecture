import 'package:flutter/material.dart';
import 'package:kaisel/kaisel.dart';
import 'package:provider/provider.dart';
import 'package:signals/signals_flutter.dart';

import '../../../../core/design_system/app_theme.g.dart';
import '../../../../core/design_system/components/app_buttons.dart';
import '../../../../core/design_system/components/app_card.dart';
import '../../../../core/design_system/components/app_notice.dart';
import '../../../../core/design_system/components/app_scaffold.dart';
import '../../domain/entities/product.dart';
import '../../shop_module.dart';
import '../view_models/shop_cart_view_model.dart';
import '../widgets/product_tile.dart';

// What is in the cart: one row per add, and what the rows add up to.
class ShopCartView extends StatelessWidget {
  const ShopCartView({super.key});

  @override
  Widget build(BuildContext context) {
    // Read once, subscribe never — `SignalBuilder` below does the rebuilding.
    final viewModel = context.read<ShopCartViewModel>();

    return SignalBuilder(
      builder: (context) => AppScaffold(
        title: const Text('Cart'),
        body: _buildBody(context, viewModel, viewModel.products.value),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ShopCartViewModel viewModel,
    AsyncState<List<Product>> state,
  ) {
    final theme = context.theme;

    // Value and failure arms first: both reload variants are `AsyncLoading`.
    return switch (state) {
      // An empty cart is a value, not a failure: the read worked.
      AsyncData<List<Product>>(:final value) when value.isEmpty =>
        const AppNotice(
          icon: Icons.shopping_cart_outlined,
          message: 'Your cart is empty.',
        ),
      AsyncData<List<Product>>(:final value) => _buildCart(
        context,
        viewModel,
        value,
      ),
      AsyncError<List<Product>>() => AppNotice(
        icon: Icons.cloud_off_outlined,
        message: 'Could not load the cart.',
        isFailure: true,
        action: AppFilledButton(label: 'Try again', onPressed: viewModel.load),
      ),
      AsyncLoading<List<Product>>() => Center(
        child: CircularProgressIndicator(color: theme.colors.brand.primary),
      ),
    };
  }

  Widget _buildCart(
    BuildContext context,
    ShopCartViewModel viewModel,
    List<Product> products,
  ) {
    final theme = context.theme;

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
                  viewModel.total.value.toStringAsFixed(2),
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
