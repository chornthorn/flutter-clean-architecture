import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/app/app_codec.dart';
import 'package:flutter_x/app/app_route.dart';
import 'package:flutter_x/features/posts/posts_module.dart';
import 'package:flutter_x/features/settings/settings_module.dart';
import 'package:flutter_x/features/shop/shop_module.dart';
import 'package:kaisel/kaisel.dart';

void main() {
  group('appCodec.decode', () {
    test('should map the root path to the home mount', () {
      expect(
        appCodec.decode(Uri.parse('/')),
        KaiselConfig<AppRoute>(mainStack: const [HomeMount()]),
      );
    });

    test('should map a bare module prefix to the module root', () {
      expect(
        appCodec.decode(Uri.parse('/shop')),
        KaiselConfig<AppRoute>(
          mainStack: const [ShopMount()],
          nestedState: KaiselModuleConfig(stack: const [ShopHome()]),
        ),
      );
    });

    test('should map a module URL to its mount plus the module stack', () {
      expect(
        appCodec.decode(Uri.parse('/shop/products/sku-42')),
        KaiselConfig<AppRoute>(
          mainStack: const [ShopMount()],
          nestedState: KaiselModuleConfig(
            stack: const [ShopHome(), ShopProduct('sku-42')],
          ),
        ),
      );
    });

    test('should map the cart URL to the cart above the module root', () {
      expect(
        appCodec.decode(Uri.parse('/shop/cart')),
        KaiselConfig<AppRoute>(
          mainStack: const [ShopMount()],
          nestedState: KaiselModuleConfig(
            stack: const [ShopHome(), ShopCart()],
          ),
        ),
      );
    });

    test('should map a second module independently of the first', () {
      expect(
        appCodec.decode(Uri.parse('/settings/about')),
        KaiselConfig<AppRoute>(
          mainStack: const [SettingsMount()],
          nestedState: KaiselModuleConfig(
            stack: const [SettingsHome(), SettingsAbout()],
          ),
        ),
      );
    });

    test('should map the posts URL to the posts mount', () {
      expect(
        appCodec.decode(Uri.parse('/posts')),
        KaiselConfig<AppRoute>(
          mainStack: const [PostsMount()],
          nestedState: KaiselModuleConfig(stack: const [PostsHome()]),
        ),
      );
    });

    test('should map a post URL to the detail above the module root', () {
      expect(
        appCodec.decode(Uri.parse('/posts/7')),
        KaiselConfig<AppRoute>(
          mainStack: const [PostsMount()],
          nestedState: KaiselModuleConfig(
            stack: const [PostsHome(), PostDetail(7)],
          ),
        ),
      );
    });

    test('should not claim a post path whose id is not a number', () {
      expect(appCodec.decode(Uri.parse('/posts/all')), isNull);
    });

    test('should return null for an unknown host path', () {
      expect(appCodec.decode(Uri.parse('/nope')), isNull);
    });

    test('should return null for an unknown path inside a module prefix', () {
      // It belongs to that module: the base codec must not claim it.
      expect(appCodec.decode(Uri.parse('/shop/nope')), isNull);
    });
  });

  group('appCodec.encode', () {
    const paths = [
      '/',
      '/shop',
      '/shop/products/sku-42',
      '/shop/cart',
      '/settings',
      '/settings/about',
      '/posts',
      '/posts/7',
    ];

    for (final path in paths) {
      test('should round-trip $path through decode and encode', () {
        final config = appCodec.decode(Uri.parse(path));

        expect(config, isNotNull, reason: '$path should decode');
        expect(
          appCodec.encode(config!).toString(),
          path,
          reason: '$path should survive a round-trip',
        );
      });
    }
  });
}
