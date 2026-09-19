import 'package:kaisel_generator/src/emitter/default_import_emitter.dart';
import 'package:kaisel_generator/src/emitter/default_registry_emitter.dart';
import 'package:kaisel_generator/src/model/micro_package.dart';
import 'package:kaisel_generator/src/model/module_info.dart';
import 'package:test/test.dart';

void main() {
  const emitter = DefaultRegistryEmitter(imports: DefaultImportEmitter());

  test('should compose an external micro-package into the host', () {
    final code = emitter.write(
      modules: [
        _module(
          mountName: 'HomeMount',
          routeType: 'HomeRoute',
          filePath: '/app/lib/home_module.dart',
          isInitial: true,
        ),
      ],
      routeClass: 'AppRoute',
      initialRouteOverride: null,
      microPackages: [
        _microPackage(
          className: 'FeatureShopKaiselModule',
          importUri: 'package:feature_shop/feature_shop.kaisel.dart',
          mounts: const [
            MicroPackageMountInfo(fieldName: 'shopMount', isRouted: true, isInitial: false),
          ],
        ),
      ],
      packageName: 'flutter_x',
      libDir: '/app/lib',
    );

    expect(code, contains("import 'package:kaisel_generator/micro_mount.dart';"));
    expect(code, contains("import 'package:feature_shop/feature_shop.kaisel.dart' as _mp1;"));
    expect(code, contains('final class ShopMount extends AppRoute'));
    // Pages and URLs come from the package's declaration...
    expect(code, contains('ShopMount() => _mp1.FeatureShopKaiselModule.shopMount.page,'));
    expect(code, contains('ShopMount() => _mp1.FeatureShopKaiselModule.shopMount.url,'));
    // ...and the host binds it to its own marker instance, not to a name.
    expect(
      code,
      contains('_mp1.FeatureShopKaiselModule.shopMount.moduleMount(const ShopMount()),'),
    );
    expect(code, contains('const AppRoute kInitialAppRoute = HomeMount();'));
    // A package in the list makes the mounts and the codec non-const.
    expect(code, contains('final List<ModuleMount<AppRoute>> appModuleMounts = ['));
    expect(code, contains('  baseCodec: const DefaultBaseAppCodec(),'));
  });

  test('should keep the generated code const when nothing is composed', () {
    final code = emitter.write(
      modules: [
        _module(mountName: 'ShopMount', prefix: '/shop', filePath: '/app/lib/shop_module.dart'),
      ],
      routeClass: 'AppRoute',
      initialRouteOverride: null,
      microPackages: const [],
      packageName: 'flutter_x',
      libDir: '/app/lib',
    );

    expect(code, isNot(contains('micro_mount.dart')));
    expect(code, contains('const List<ModuleMount<AppRoute>> appModuleMounts = ['));
    expect(code, contains('const defaultAppCodec = ConfigCodecWithModules<AppRoute>('));
    expect(code, contains('  baseCodec: DefaultBaseAppCodec(),'));
  });

  test("should land on a package's initial mount when the host marks none", () {
    final code = emitter.write(
      modules: [
        _module(mountName: 'ShopMount', prefix: '/shop', filePath: '/app/lib/shop_module.dart'),
      ],
      routeClass: 'AppRoute',
      initialRouteOverride: null,
      microPackages: [
        _microPackage(
          className: 'ProfileKaiselModule',
          importUri: 'package:profile/profile.kaisel.dart',
          mounts: const [
            MicroPackageMountInfo(fieldName: 'profileMount', isRouted: true, isInitial: true),
          ],
        ),
      ],
      packageName: 'flutter_x',
      libDir: '/app/lib',
    );

    expect(code, contains('const AppRoute kInitialAppRoute = ProfileMount();'));
  });

  test('should prefer an explicit initial route over every module', () {
    final code = emitter.write(
      modules: [
        _module(
          mountName: 'HomeMount',
          routeType: 'HomeRoute',
          filePath: '/app/lib/home_module.dart',
          isInitial: true,
        ),
      ],
      routeClass: 'AppRoute',
      initialRouteOverride: 'ShopMount',
      microPackages: const [],
      packageName: 'flutter_x',
      libDir: '/app/lib',
    );

    expect(code, contains('const AppRoute kInitialAppRoute = ShopMount();'));
  });

  test('should order mounts longest prefix first', () {
    final code = emitter.write(
      modules: [
        _module(mountName: 'ShopMount', prefix: '/shop', filePath: '/app/lib/shop_module.dart'),
        _module(
          mountName: 'ShopV2Mount',
          prefix: '/shop/v2',
          filePath: '/app/lib/shop_v2_module.dart',
        ),
        _module(mountName: 'PostsMount', prefix: '/posts', filePath: '/app/lib/posts_module.dart'),
      ],
      routeClass: 'AppRoute',
      initialRouteOverride: null,
      microPackages: const [],
      packageName: 'flutter_x',
      libDir: '/app/lib',
    );

    final v2 = code.indexOf('mountRoute: ShopV2Mount(),');
    final shop = code.indexOf('mountRoute: ShopMount(),');
    final posts = code.indexOf('mountRoute: PostsMount(),');
    expect(v2, greaterThanOrEqualTo(0));
    expect(v2, lessThan(posts));
    expect(posts, lessThan(shop));
  });

  test('should alias the host modules it imports', () {
    final code = emitter.write(
      modules: [
        _module(
          mountName: 'ShopMount',
          prefix: '/shop',
          filePath: '/app/lib/features/shop/shop_module.dart',
        ),
        _module(
          mountName: 'PostsMount',
          prefix: '/posts',
          filePath: '/app/lib/features/posts/posts_module.dart',
        ),
      ],
      routeClass: 'AppRoute',
      initialRouteOverride: null,
      microPackages: const [],
      packageName: 'flutter_x',
      libDir: '/app/lib',
    );

    expect(
      code,
      contains("import 'package:flutter_x/features/posts/posts_module.dart' as _i1;"),
    );
    expect(
      code,
      contains("import 'package:flutter_x/features/shop/shop_module.dart' as _i2;"),
    );
  });
}

ModuleInfo _module({
  String className = 'ShopRouterModule',
  String routeType = 'ShopRoute',
  required String mountName,
  required String filePath,
  String? prefix,
  bool isInitial = false,
}) =>
    ModuleInfo(
      className: className,
      routeType: routeType,
      mountName: mountName,
      codecName: '${routeType}Codec',
      filePath: filePath,
      prefix: prefix,
      isInitial: isInitial,
    );

MicroPackageInfo _microPackage({
  required String className,
  required String importUri,
  required List<MicroPackageMountInfo> mounts,
}) =>
    MicroPackageInfo(className: className, importUri: importUri, mounts: mounts);
