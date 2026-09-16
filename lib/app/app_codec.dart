import 'package:kaisel/kaisel.dart';

import '../features/posts/posts_module.dart';
import '../features/settings/settings_module.dart';
import '../features/shop/shop_module.dart';
import 'app_route.dart';

// URL mapping for the host's own routes.
class BaseAppCodec extends KaiselConfigCodec<AppRoute> {
  const BaseAppCodec();

  @override
  KaiselConfig<AppRoute>? decode(Uri uri) {
    final segments = uri.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);

    return switch (segments) {
      [] => KaiselConfig(mainStack: const [HomeMount()]),
      _ => null, // Unrecognised — the parser uses its fallback stack.
    };
  }

  // The composer usually encodes these; the exhaustive switch needs them anyway.
  @override
  Uri encode(KaiselConfig<AppRoute> config) {
    return switch (config.mainStack.last) {
      HomeMount() => Uri(path: '/'),
      ShopMount() => Uri(path: '/shop'),
      SettingsMount() => Uri(path: '/settings'),
      PostsMount() => Uri(path: '/posts'),
    };
  }
}

// The host stack decodes to a single mount, so a deep link has no history behind it.
const appCodec = ConfigCodecWithModules<AppRoute>(
  baseCodec: BaseAppCodec(),
  modules: [
    ModuleMount(
      mountRoute: ShopMount(),
      prefix: '/shop',
      codec: ShopRouteCodec(),
    ),
    ModuleMount(
      mountRoute: SettingsMount(),
      prefix: '/settings',
      codec: SettingsRouteCodec(),
    ),
    ModuleMount(
      mountRoute: PostsMount(),
      prefix: '/posts',
      codec: PostsRouteCodec(),
    ),
  ],
);
