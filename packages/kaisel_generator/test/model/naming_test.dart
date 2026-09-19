import 'package:kaisel_generator/src/model/naming.dart';
import 'package:test/test.dart';

void main() {
  group('toSnakeCase', () {
    test('should split a camel case name on word boundaries', () {
      expect(toSnakeCase('FeatureShop'), 'feature_shop');
      expect(toSnakeCase('Shop'), 'shop');
    });

    test('should not double an underscore that is already there', () {
      expect(toSnakeCase('feature_shop'), 'feature_shop');
      expect(toSnakeCase('Feature_Shop'), 'feature_shop');
    });

    test('should split an acronym per letter', () {
      expect(toSnakeCase('HTTPClient'), 'h_t_t_p_client');
    });
  });

  group('toPascalCase', () {
    test('should capitalize every word', () {
      expect(toPascalCase('feature_shop'), 'FeatureShop');
      expect(toPascalCase('profile'), 'Profile');
      expect(toPascalCase('feature-shop'), 'FeatureShop');
    });

    test('should return an empty string for empty input', () {
      expect(toPascalCase(''), '');
    });
  });

  group('toCamelCase', () {
    test('should lower the first letter only', () {
      expect(toCamelCase('ShopMount'), 'shopMount');
      expect(toCamelCase('ProfileMount'), 'profileMount');
      expect(toCamelCase(''), '');
    });
  });

  group('moduleBaseName', () {
    test('should strip the module suffix from a class name', () {
      expect(moduleBaseName('ShopRouterModule'), 'Shop');
      expect(moduleBaseName('ShopModule'), 'Shop');
    });

    test('should keep a name that carries no suffix', () {
      expect(moduleBaseName('Shop'), 'Shop');
    });
  });
}
