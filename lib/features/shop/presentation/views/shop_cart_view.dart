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
    // Read once, subscribe never: what changes lives in the view model's
    // signals, and `SignalBuilder` is what rebuilds this page off the ones read
    // below.
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

    // `AsyncDataReloading` and `AsyncDataRefreshing` implement `AsyncLoading`, so
    // the arms that carry a value or a failure have to come before the loading
    // one — matching the loading arm first would swallow them.
    return switch (state) {
      // An empty cart is a value and not a failure: the read worked, and nothing
      // has been added yet.
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
                // The total the view model derives from the rows above, read
                // through the same builder.
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
