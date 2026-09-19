import 'package:flutter/material.dart';
import 'package:kaisel/kaisel.dart';
import 'package:provider/provider.dart';
import 'package:signals/signals_flutter.dart';

import '../../../../app/app.dart';
import '../../../../core/design_system/app_theme.g.dart';
import '../../../../core/design_system/components/app_buttons.dart';
import '../../../../core/design_system/components/app_notice.dart';
import '../../../../core/design_system/components/app_scaffold.dart';
import '../../domain/entities/product.dart';
import '../../shop_module.dart';
import '../view_models/shop_home_view_model.dart';
import '../widgets/cart_button.dart';
import '../widgets/product_tile.dart';

// The feature's list screen — see `docs/architecture.md` for the state shape.
class ShopHomeView extends StatelessWidget {
  const ShopHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<ShopHomeViewModel>();

    return SignalBuilder(
      builder: (context) => AppScaffold(
        title: const Text('Shop'),
        actions: [
          const CartButton(),
          // The inner navigator has nothing to pop, so this leaves the feature.
          IconButton(
            onPressed: () => context.router<AppRoute>().pop(),
            icon: const Icon(Icons.close),
            tooltip: 'Exit shop',
          ),
        ],
        body: _buildBody(context, viewModel, viewModel.products.value),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ShopHomeViewModel viewModel,
    AsyncState<List<Product>> state,
  ) {
    final theme = context.theme;

    // Value and failure arms first: both reload variants are `AsyncLoading`.
    return switch (state) {
      // An empty catalog is a value, not a failure: the read worked.
      AsyncData<List<Product>>(:final value) when value.isEmpty =>
        const AppNotice(
          icon: Icons.inventory_2_outlined,
          message: 'No products yet.',
        ),
      AsyncData<List<Product>>(:final value) => _buildProducts(context, value),
      AsyncError<List<Product>>() => AppNotice(
        icon: Icons.cloud_off_outlined,
        message: 'Could not load products.',
        isFailure: true,
        action: AppFilledButton(label: 'Try again', onPressed: viewModel.load),
      ),
      AsyncLoading<List<Product>>() => Center(
        child: CircularProgressIndicator(color: theme.colors.brand.primary),
      ),
    };
  }

  Widget _buildProducts(BuildContext context, List<Product> products) {
    final theme = context.theme;

    return ListView.separated(
      padding: EdgeInsets.all(theme.sizes.padding.md),
      itemCount: products.length,
      separatorBuilder: (context, index) =>
          SizedBox(height: theme.sizes.spacing.sm),
      itemBuilder: (context, index) {
        final product = products[index];
        return ProductTile(
          product: product,
          // `ShopProduct` is a `ShopRoute`, so this pushes inside the feature.
          onTap: () => context.push(ShopProduct(product.id)),
        );
      },
    );
  }
}
