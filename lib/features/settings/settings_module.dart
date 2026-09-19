import 'package:flutter/widgets.dart';
import 'package:kaisel/kaisel.dart';
import 'package:kaisel_generator/kaisel_generator.dart';

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

// Keep it `const`: a new instance would drop the module's navigation state.
@KaiselModule(prefix: '/settings')
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

// URL mapping under the `/settings` mount prefix.
class SettingsRouteCodec extends ModuleStackCodec<SettingsRoute> {
  const SettingsRouteCodec();

  // The composer can hand this another feature's stack for one frame.
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
