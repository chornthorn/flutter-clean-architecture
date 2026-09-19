import 'package:flutter/widgets.dart';
import 'package:injectify/injectify.dart';
import 'package:kaisel/kaisel.dart';
import 'package:kaisel_generator/kaisel_generator.dart';
import 'package:provider/provider.dart';

import '../../provider.dart';
import 'presentation/view_models/shop_cart_view_model.dart';
import 'presentation/view_models/shop_home_view_model.dart';
import 'presentation/view_models/shop_product_view_model.dart';
import 'presentation/views/shop_cart_view.dart';
import 'presentation/views/shop_home_view.dart';
import 'presentation/views/shop_product_view.dart';

// The shop feature's entry point: its injectify micro-package, routes and codec —
// see `lib/features/README.md`.
@InjectableMicroPackage(moduleName: 'Shop')
void configureShopModule() {}

// Routes for the shop feature.
sealed class ShopRoute extends KaiselRoute {
  const ShopRoute();
}

final class ShopHome extends ShopRoute {
  const ShopHome();
}

final class ShopCart extends ShopRoute {
  const ShopCart();
}

final class ShopProduct extends ShopRoute {
  const ShopProduct(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

// Kaisel module for the shop feature.
@KaiselModule(prefix: '/shop')
class ShopRouterModule extends RouteModule<ShopRoute> {
  const ShopRouterModule();

  @override
  List<ShopRoute> get initialStack => const [ShopHome()];

  @override
  Widget buildPage(BuildContext context, ShopRoute route) => switch (route) {
    ShopHome() => Provider<ShopHomeViewModel>(
      create: (_) => getIt<ShopHomeViewModel>()..load(),
      dispose: (_, viewModel) => viewModel.dispose(),
      child: const ShopHomeView(),
    ),
    ShopProduct(:final id) => Provider<ShopProductViewModel>(
      create: (_) => getIt<ShopProductViewModel>()..load(id),
      dispose: (_, viewModel) => viewModel.dispose(),
      child: ShopProductView(id: id),
    ),
    ShopCart() => Provider<ShopCartViewModel>(
      create: (_) => getIt<ShopCartViewModel>()..load(),
      dispose: (_, viewModel) => viewModel.dispose(),
      child: const ShopCartView(),
    ),
  };

  @override
  ModuleStackCodec<ShopRoute> get codec => const ShopRouteCodec();
}

// URL mapping under the `/shop` prefix.
class ShopRouteCodec extends ModuleStackCodec<ShopRoute> {
  const ShopRouteCodec();

  // The composer can hand this another feature's stack for one frame.
  @override
  List<String> encodeAny(List<KaiselRoute> stack) {
    final top = stack.last;
    if (top is! ShopRoute) return const [];
    return encode(<ShopRoute>[top]);
  }

  @override
  List<String> encode(List<ShopRoute> stack) => switch (stack.last) {
    ShopHome() => const [],
    ShopProduct(:final id) => ['products', id],
    ShopCart() => const ['cart'],
  };

  @override
  List<ShopRoute>? decode(List<String> segments) => switch (segments) {
    [] => const [ShopHome()],
    ['products', final id] => [const ShopHome(), ShopProduct(id)],
    ['cart'] => const [ShopHome(), ShopCart()],
    _ => null,
  };
}
