import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:signals/signals_flutter.dart';

import '../../../../core/design_system/app_theme.g.dart';
import '../../../../core/design_system/components/app_buttons.dart';
import '../../../../core/design_system/components/app_card.dart';
import '../../../../core/design_system/components/app_failure_line.dart';
import '../../../../core/design_system/components/app_notice.dart';
import '../../../../core/design_system/components/app_scaffold.dart';
import '../../domain/entities/product.dart';
import '../view_models/shop_product_view_model.dart';
import '../widgets/cart_button.dart';

// One product, looked up by the id on `ShopProduct`; see `docs/architecture.md`.
class ShopProductView extends StatelessWidget {
  const ShopProductView({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    // Read once, subscribe never — `SignalBuilder` below does the rebuilding.
    final viewModel = context.read<ShopProductViewModel>();

    return SignalBuilder(
      builder: (context) => AppScaffold(
        title: Text(id),
        actions: const [CartButton()],
        body: _buildBody(context, viewModel),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ShopProductViewModel viewModel) {
    final theme = context.theme;

    // Value and failure arms first: both reload variants are `AsyncLoading`.
    return switch (viewModel.product.value) {
      AsyncData<Product?>(:final value) when value != null => _buildProduct(
        context,
        viewModel,
        value,
      ),
      AsyncError<Product?>() => AppNotice(
        icon: Icons.cloud_off_outlined,
        message: 'Could not load the product.',
        isFailure: true,
        action: AppFilledButton(
          label: 'Try again',
          onPressed: () => viewModel.load(id),
        ),
      ),
      // A missing product is an answer, not a failure: only the error is retried.
      AsyncData<Product?>() => const AppNotice(
        icon: Icons.search_off_outlined,
        message: 'Product not found.',
      ),
      AsyncLoading<Product?>() => Center(
        child: CircularProgressIndicator(color: theme.colors.brand.primary),
      ),
    };
  }

  Widget _buildProduct(
    BuildContext context,
    ShopProductViewModel viewModel,
    Product product,
  ) {
    final theme = context.theme;

    return SingleChildScrollView(
      padding: EdgeInsets.all(theme.sizes.padding.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          // The add's state, not an error shared with the read above it.
          if (viewModel.add.value.hasError)
            const AppFailureLine(message: 'Could not add to cart.')
          else
            Text(
              '${viewModel.cartCount.value} in cart',
              style: theme.typography.label.regular,
            ),
        ],
      ),
    );
  }
}
