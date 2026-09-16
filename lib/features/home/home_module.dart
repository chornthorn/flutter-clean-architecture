import 'package:flutter/widgets.dart';
import 'package:kaisel/kaisel.dart';

import 'presentation/views/home_view.dart';

// Routes for the home feature.
sealed class HomeRoute extends KaiselRoute {
  const HomeRoute();
}

// The feature's only screen: the app's landing menu.
final class HomeRoot extends HomeRoute {
  const HomeRoot();
}

// The home feature as a kaisel module.
//
// No codec: one screen has no sub-URLs, so the root path is owned by
// `BaseAppCodec` in `lib/app/`.
//
// Keep it `const` — `KaiselModuleMount` rebuilds the router when the module
// instance changes, dropping its navigation state.
class HomeRouterModule extends RouteModule<HomeRoute> {
  const HomeRouterModule();

  @override
  List<HomeRoute> get initialStack => const [HomeRoot()];

  @override
  Widget buildPage(BuildContext context, HomeRoute route) => switch (route) {
    HomeRoot() => const HomeView(),
  };
}
