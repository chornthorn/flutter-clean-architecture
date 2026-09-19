import 'package:kaisel_generator/src/emitter/default_import_emitter.dart';
import 'package:kaisel_generator/src/emitter/default_manifest_emitter.dart';
import 'package:kaisel_generator/src/model/module_info.dart';
import 'package:test/test.dart';

void main() {
  const emitter = DefaultManifestEmitter(imports: DefaultImportEmitter());

  test('should declare one typed mount per module', () {
    final code = emitter.write(
      moduleName: 'FeatureShop',
      modules: [
        _module(
          className: 'ShopRouterModule',
          mountName: 'ShopMount',
          prefix: '/products',
          filePath: '/shop/lib/src/shop_module.dart',
        ),
      ],
      packageName: 'feature_shop',
      libDir: '/shop/lib',
      basePrefix: '/shop',
    );

    expect(code, contains("import 'package:kaisel_generator/micro_mount.dart';"));
    expect(code, contains('abstract final class FeatureShopKaiselModule {'));
    expect(code, contains('static const KaiselMicroMount<i1.ShopRoute> shopMount ='));
    expect(code, contains('    module: i1.ShopRouterModule(),'));
    expect(code, contains('    codec: i1.ShopRouteCodec(),'));
    expect(code, contains("    prefix: '/shop/products',"));
    expect(code, isNot(contains('mountNames')));
    // A manifest is a typed contract: nothing for a host to dispatch on by name.
    expect(code, isNot(contains('isInitial')));
  });

  test('should omit prefix and isInitial when the module declares neither', () {
    final code = emitter.write(
      moduleName: 'FeatureShop',
      modules: [
        _module(
          mountName: 'HomeMount',
          routeType: 'HomeRoute',
          filePath: '/shop/lib/home_module.dart',
        ),
      ],
      packageName: 'feature_shop',
      libDir: '/shop/lib',
      basePrefix: null,
    );

    expect(code, contains('static const KaiselMicroMount<i1.HomeRoute> homeMount ='));
    expect(code, isNot(contains('prefix:')));
    expect(code, isNot(contains('isInitial')));
  });

  test('should mark the landing mount and alias every imported file', () {
    final code = emitter.write(
      moduleName: 'FeatureShop',
      modules: [
        _module(
          mountName: 'HomeMount',
          routeType: 'HomeRoute',
          filePath: '/shop/lib/home_module.dart',
          isInitial: true,
        ),
        _module(
          mountName: 'CartMount',
          routeType: 'CartRoute',
          filePath: '/shop/lib/cart_module.dart',
          prefix: '/cart',
        ),
      ],
      packageName: 'feature_shop',
      libDir: '/shop/lib',
      basePrefix: null,
    );

    expect(code, contains("import 'package:feature_shop/cart_module.dart' as i1;"));
    expect(code, contains("import 'package:feature_shop/home_module.dart' as i2;"));
    expect(code, contains('    isInitial: true,'));
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
