import 'package:flutter/widgets.dart';
import 'package:injectify/injectify.dart';
import 'package:kaisel/kaisel.dart';
import 'package:provider/provider.dart';

import '../../provider.dart';
import 'presentation/view_models/shop_home_view_model.dart';
import 'presentation/view_models/shop_product_view_model.dart';
import 'presentation/views/shop_home_view.dart';
import 'presentation/views/shop_product_view.dart';

// The shop feature's injectify micro-package: every `@Injectable` class under
// `lib/features/shop/` is registered by this module and by nothing else.
@InjectableMicroPackage(moduleName: 'Shop')
void configureShopModule() {}

// Routes for the shop feature.
sealed class ShopRoute extends KaiselRoute {
  const ShopRoute();
}

final class ShopHome extends ShopRoute {
  const ShopHome();
}

final class ShopProduct extends ShopRoute {
  const ShopProduct(this.id);

  final String id;

  // Equality is by `props`.
  @override
  List<Object?> get props => [id];
}

// Kaisel module for the shop feature. Keep it `const` — kaisel rebuilds the
// router when the module instance changes.
class ShopRouterModule extends RouteModule<ShopRoute> {
  const ShopRouterModule();

  @override
  List<ShopRoute> get initialStack => const [ShopHome()];

  @override
  Widget buildPage(BuildContext context, ShopRoute route) => switch (route) {
    ShopHome() => ChangeNotifierProvider<ShopHomeViewModel>(
      create: (_) => getIt<ShopHomeViewModel>()..load(),
      child: const ShopHomeView(),
    ),
    // Load in `create:` — a notify during mount trips a provider assertion.
    ShopProduct(:final id) => ChangeNotifierProvider<ShopProductViewModel>(
      create: (_) => getIt<ShopProductViewModel>()..load(id),
      child: ShopProductView(id: id),
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
  };

  @override
  List<ShopRoute>? decode(List<String> segments) => switch (segments) {
    [] => const [ShopHome()],
    ['products', final id] => [const ShopHome(), ShopProduct(id)],
    _ => null,
  };
}
