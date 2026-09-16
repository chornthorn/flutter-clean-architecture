import 'package:kaisel/kaisel.dart';

import '../features/posts/posts_module.dart';
import '../features/settings/settings_module.dart';
import '../features/shop/shop_module.dart';
import 'app_route.dart';

// URL mapping for the host's own routes. Feature URLs never reach here.
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

  // Mount arms are normally encoded by the composer; they keep the switch
  // exhaustive and stay correct if this codec is used on its own.
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

// The app-wide codec: host routes via [BaseAppCodec], `/shop` and `/settings`
// delegated to the feature that owns each namespace.
//
// The home feature is deliberately absent: one screen has no sub-URLs, and an
// empty mount prefix would match every path.
//
// Note the decode shape: `mainStack: [mountRoute]` with nothing beneath it, so a
// cold deep link lands with no history behind it.
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
