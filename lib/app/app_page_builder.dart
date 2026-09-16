import 'package:flutter/widgets.dart';
import 'package:kaisel/kaisel.dart';

import '../features/home/home_module.dart';
import '../features/settings/settings_module.dart';
import '../features/shop/shop_module.dart';
import 'app_route.dart';

// Host-owned routes are mount markers; each feature's own routes never appear
// here — `KaiselModuleMount` dispatches those internally.
Widget buildAppPage(BuildContext context, AppRoute route) => switch (route) {
  HomeMount() => const KaiselModuleMount<HomeRoute>(module: HomeRouterModule()),
  ShopMount() => const KaiselModuleMount<ShopRoute>(module: ShopRouterModule()),
  SettingsMount() => const KaiselModuleMount<SettingsRoute>(
    module: SettingsRouterModule(),
  ),
};
