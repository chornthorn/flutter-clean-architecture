import 'package:flutter/widgets.dart';
import 'package:kaisel/kaisel.dart';

import 'presentation/views/settings_about_view.dart';
import 'presentation/views/settings_home_view.dart';

// Routes for the settings feature.
sealed class SettingsRoute extends KaiselRoute {
  const SettingsRoute();
}

final class SettingsHome extends SettingsRoute {
  const SettingsHome();
}

final class SettingsAbout extends SettingsRoute {
  const SettingsAbout();
}

// The settings feature as a kaisel module.
//
// Its screens read no state, so it has no `domain/` or `infrastructure/` layer
// and nothing to register with the container yet.
//
// Keep it `const` — see `HomeRouterModule`.
class SettingsRouterModule extends RouteModule<SettingsRoute> {
  const SettingsRouterModule();

  @override
  List<SettingsRoute> get initialStack => const [SettingsHome()];

  @override
  Widget buildPage(BuildContext context, SettingsRoute route) =>
      switch (route) {
        SettingsHome() => const SettingsHomeView(),
        SettingsAbout() => const SettingsAboutView(),
      };

  @override
  ModuleStackCodec<SettingsRoute> get codec => const SettingsRouteCodec();
}

// URL mapping under the `/settings` mount prefix. See `ShopRouteCodec` for the
// conventions both features follow.
class SettingsRouteCodec extends ModuleStackCodec<SettingsRoute> {
  const SettingsRouteCodec();

  // Same guard as `ShopRouteCodec.encodeAny`, same reason.
  @override
  List<String> encodeAny(List<KaiselRoute> stack) {
    final top = stack.last;
    if (top is! SettingsRoute) return const [];
    return encode(<SettingsRoute>[top]);
  }

  @override
  List<String> encode(List<SettingsRoute> stack) => switch (stack.last) {
    SettingsHome() => const [],
    SettingsAbout() => const ['about'],
  };

  @override
  List<SettingsRoute>? decode(List<String> segments) => switch (segments) {
    [] => const [SettingsHome()],
    ['about'] => const [SettingsHome(), SettingsAbout()],
    _ => null,
  };
}
