import 'package:flutter/widgets.dart';
import 'package:kaisel/kaisel.dart';

import '../features/home/home_module.dart';
import '../features/posts/posts_module.dart';
import '../features/settings/settings_module.dart';
import '../features/shop/shop_module.dart';
import 'app_route.dart';

// Mount markers: `KaiselModuleMount` dispatches each feature's own routes.
Widget buildAppPage(BuildContext context, AppRoute route) => switch (route) {
  HomeMount() => const KaiselModuleMount<HomeRoute>(module: HomeRouterModule()),
  ShopMount() => const KaiselModuleMount<ShopRoute>(module: ShopRouterModule()),
  SettingsMount() => const KaiselModuleMount<SettingsRoute>(
    module: SettingsRouterModule(),
  ),
  PostsMount() => const KaiselModuleMount<PostsRoute>(
    module: PostsRouterModule(),
  ),
};
