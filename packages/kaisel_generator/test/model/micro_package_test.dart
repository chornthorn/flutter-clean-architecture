import 'package:kaisel_generator/src/helper/naming.dart';
import 'package:kaisel_generator/src/models/scan.dart';
import 'package:test/test.dart';

void main() {
  group('MicroPackageMountInfo', () {
    const mount = MicroPackageMountInfo(
      fieldName: 'shopMount',
      isRouted: true,
      isInitial: false,
    );

    test('should derive the marker the host is asked for', () {
      expect(mount.mountName, 'ShopMount');
      expect(mount.marker, 'ShopMount');
    });

    test('should prefer the marker name the host qualified', () {
      expect(
          mount.withHostMarker('ShopProfileMount').marker, 'ShopProfileMount');
    });
  });

  group('MicroPackageInfo', () {
    test('should name itself after its registry class', () {
      const package = MicroPackageInfo(
        className: 'ProfileKaiselModule',
        importUri: 'package:profile/profile.kaisel.dart',
        mounts: [],
      );

      expect(package.owner, 'Profile');
    });

    test('should find the mount the host lands on', () {
      const package = MicroPackageInfo(
        className: 'FeatureShopKaiselModule',
        importUri: 'package:feature_shop/feature_shop.kaisel.dart',
        mounts: [
          MicroPackageMountInfo(
              fieldName: 'homeMount', isRouted: false, isInitial: true),
          MicroPackageMountInfo(
              fieldName: 'cartMount', isRouted: true, isInitial: false),
        ],
      );

      expect(package.initialMount?.marker, 'HomeMount');
    });

    test('should have no landing mount when none is marked', () {
      const package = MicroPackageInfo(
        className: 'FeatureShopKaiselModule',
        importUri: 'package:feature_shop/feature_shop.kaisel.dart',
        mounts: [
          MicroPackageMountInfo(
              fieldName: 'cartMount', isRouted: true, isInitial: false),
        ],
      );

      expect(package.initialMount, isNull);
    });
  });

  group('qualifyMarkers', () {
    test('should leave a free name alone', () {
      final qualified = qualifyMarkers(
        [_microPackage('ProfileKaiselModule', 'profileMount')],
        [_module('HomeMount')],
      );

      expect(qualified.single.mounts.single.marker, 'ProfileMount');
    });

    test('should insert the owner when the host already uses the name', () {
      final qualified = qualifyMarkers(
        [_microPackage('ProfileKaiselModule', 'shopMount')],
        [_module('ShopMount')],
      );

      expect(qualified.single.mounts.single.marker, 'ShopProfileMount');
    });

    test('should keep two packages claiming one name distinct', () {
      final qualified = qualifyMarkers(
        [
          _microPackage('ProfileKaiselModule', 'shopMount'),
          _microPackage('FeatureShopKaiselModule', 'shopMount'),
        ],
        [_module('ShopMount')],
      );

      expect(qualified.first.mounts.single.marker, 'ShopProfileMount');
      expect(qualified.last.mounts.single.marker, 'ShopFeatureShopMount');
    });

    test('should leave the packages it was given untouched', () {
      final packages = [_microPackage('ProfileKaiselModule', 'shopMount')];

      qualifyMarkers(packages, [_module('ShopMount')]);

      expect(packages.single.mounts.single.marker, 'ShopMount');
    });
  });
}

MicroPackageInfo _microPackage(String className, String fieldName) =>
    MicroPackageInfo(
      className: className,
      importUri: 'package:shop/shop.kaisel.dart',
      mounts: [
        MicroPackageMountInfo(
            fieldName: fieldName, isRouted: true, isInitial: false),
      ],
    );

ModuleInfo _module(String mountName) => ModuleInfo(
      className: 'ShopRouterModule',
      routeType: 'ShopRoute',
      mountName: mountName,
      codecName: 'ShopRouteCodec',
      filePath: '/app/lib/shop_module.dart',
      prefix: '/shop',
    );
