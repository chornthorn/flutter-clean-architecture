import 'package:flutter/widgets.dart';
import 'package:kaisel/kaisel.dart';

import 'presentation/views/home_view.dart';

// Routes for the home feature.
sealed class HomeRoute extends KaiselRoute {
  const HomeRoute();
}

final class HomeRoot extends HomeRoute {
  const HomeRoot();
}

// The home feature as a kaisel module. No codec: see `lib/features/README.md`.
// Keep it `const`: a new instance would drop the module's navigation state.
class HomeRouterModule extends RouteModule<HomeRoute> {
  const HomeRouterModule();

  @override
  List<HomeRoute> get initialStack => const [HomeRoot()];

  @override
  Widget buildPage(BuildContext context, HomeRoute route) => switch (route) {
    HomeRoot() => const HomeView(),
  };
}
