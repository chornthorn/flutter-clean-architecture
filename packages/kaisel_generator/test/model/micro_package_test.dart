import 'package:kaisel_generator/src/model/micro_package.dart';
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
      expect(mount.withHostMarker('ShopProfileMount').marker, 'ShopProfileMount');
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
          MicroPackageMountInfo(fieldName: 'homeMount', isRouted: false, isInitial: true),
          MicroPackageMountInfo(fieldName: 'cartMount', isRouted: true, isInitial: false),
        ],
      );

      expect(package.initialMount?.marker, 'HomeMount');
    });

    test('should have no landing mount when none is marked', () {
      const package = MicroPackageInfo(
        className: 'FeatureShopKaiselModule',
        importUri: 'package:feature_shop/feature_shop.kaisel.dart',
        mounts: [
          MicroPackageMountInfo(fieldName: 'cartMount', isRouted: true, isInitial: false),
        ],
      );

      expect(package.initialMount, isNull);
    });
  });
}
