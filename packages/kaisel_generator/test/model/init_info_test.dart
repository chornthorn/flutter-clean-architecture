import 'package:kaisel_generator/src/model/init_info.dart';
import 'package:test/test.dart';

void main() {
  group('ExternalMicroPackageReference.importUri', () {
    test('should prefer the import the host passed', () {
      const reference = ExternalMicroPackageReference(
        module: 'FeatureShopKaiselModule',
        import: 'package:shop/src/shop.kaisel.dart',
      );

      expect(reference.importUri, 'package:shop/src/shop.kaisel.dart');
    });

    test('should infer the conventional manifest URI', () {
      const reference = ExternalMicroPackageReference(module: 'FeatureShopKaiselModule');

      expect(reference.importUri, 'package:feature_shop/feature_shop.kaisel.dart');
    });

    test('should return null when the name carries no package', () {
      const reference = ExternalMicroPackageReference(module: 'ShopModule');

      expect(reference.importUri, isNotNull);
      expect(
        const ExternalMicroPackageReference(module: 'Module').importUri,
        isNull,
      );
    });
  });
}
