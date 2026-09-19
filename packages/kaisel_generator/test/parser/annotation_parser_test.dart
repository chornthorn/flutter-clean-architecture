import 'package:kaisel_generator/src/parser/annotation_parser.dart';
import 'package:test/test.dart';

void main() {
  const parser = AnnotationParser();

  group('parseModules', () {
    test('should read prefix, mount and explicit codec from the annotation', () {
      final modules = parser.parseModules('lib/features/shop/shop_module.dart', '''
import 'package:kaisel/kaisel.dart';
import 'package:kaisel_generator/kaisel_generator.dart';

@KaiselModule(prefix: '/shop', mount: 'ShopMount', codec: ShopRouteCodec)
class ShopRouterModule extends RouteModule<ShopRoute> {
  const ShopRouterModule();
}
''');

      expect(modules, hasLength(1));
      final module = modules.single;
      expect(module.className, 'ShopRouterModule');
      expect(module.routeType, 'ShopRoute');
      expect(module.mountName, 'ShopMount');
      expect(module.prefix, '/shop');
      expect(module.codecName, 'ShopRouteCodec');
      expect(module.isInitial, isFalse);
      expect(module.isRouted, isTrue);
      expect(module.filePath, 'lib/features/shop/shop_module.dart');
    });

    test('should mark the initial module and default its names from the class', () {
      final modules = parser.parseModules('lib/features/home/home_module.dart', '''
@KaiselModule(isInitial: true)
class HomeRouterModule extends RouteModule<HomeRoute> {
  const HomeRouterModule();
}
''');

      final module = modules.single;
      expect(module.isInitial, isTrue);
      expect(module.mountName, 'HomeMount');
      expect(module.routeType, 'HomeRoute');
      expect(module.prefix, isNull);
      expect(module.isRouted, isFalse);
    });

    test('should derive the route type from a module named without RouterModule', () {
      final modules = parser.parseModules('lib/shop_module.dart', '''
@KaiselModule(prefix: '/shop')
class ShopModule extends RouteModule<ShopRoute> {
  const ShopModule();
}
''');

      expect(modules.single.mountName, 'ShopMount');
      expect(modules.single.routeType, 'ShopRoute');
    });

    test('should read the codec from the module getter', () {
      final modules = parser.parseModules('lib/shop_module.dart', '''
@KaiselModule(prefix: '/shop')
class ShopRouterModule extends RouteModule<ShopRoute> {
  const ShopRouterModule();

  @override
  ModuleStackCodec<ShopRoute> get codec => const ShopRouteCodec();
}
''');

      expect(modules.single.codecName, 'ShopRouteCodec');
    });

    test('should fall back to <RouteType>Codec when the module declares none', () {
      final modules = parser.parseModules('lib/home_module.dart', '''
@KaiselModule()
class HomeRouterModule extends RouteModule<HomeRoute> {
  const HomeRouterModule();
}
''');

      expect(modules.single.codecName, 'HomeRouteCodec');
    });

    test('should read a const-constructed codec in the annotation', () {
      final modules = parser.parseModules('lib/shop_module.dart', '''
@KaiselModule(codec: const ShopRouteCodec())
class ShopRouterModule extends RouteModule<ShopRoute> {
  const ShopRouterModule();
}
''');

      expect(modules.single.codecName, 'ShopRouteCodec');
    });

    test('should ignore a class the annotation does not mark', () {
      final modules = parser.parseModules('lib/shop_module.dart', '''
class ShopRouterModule extends RouteModule<ShopRoute> {
  const ShopRouterModule();
}

@SomethingElse()
class NotAModule {
  const NotAModule();
}
''');

      expect(modules, isEmpty);
    });

    test('should keep the declaration order of several modules in one file', () {
      final modules = parser.parseModules('lib/modules.dart', '''
@KaiselModule(prefix: '/b')
class BRouterModule extends RouteModule<BRoute> {
  const BRouterModule();
}

@KaiselModule(prefix: '/a')
class ARouterModule extends RouteModule<ARoute> {
  const ARouterModule();
}
''');

      expect(
        modules.map((module) => module.mountName),
        ['BMount', 'AMount'],
      );
    });
  });

  group('parseInit', () {
    test('should read the configuration of an init function', () {
      final init = parser.parseInit('''
import 'package:kaisel_generator/kaisel_generator.dart';

@KaiselInit(
  output: 'lib/app/generated.dart',
  routeClass: 'Route',
  initialRoute: 'HomeMount',
  externalMicroPackages: [
    ExternalMicroPackage(FeatureShopKaiselModule),
    ExternalMicroPackage(
      FeaturePostsKaiselModule,
      import: 'package:feature_posts/src/posts.kaisel.dart',
    ),
  ],
)
void configureRouting() {}
''');

      expect(init, isNotNull);
      expect(init!.output, 'lib/app/generated.dart');
      expect(init.routeClass, 'Route');
      expect(init.initialRoute, 'HomeMount');
      expect(
        init.externalMicroPackages.map((reference) => reference.module),
        ['FeatureShopKaiselModule', 'FeaturePostsKaiselModule'],
      );
      expect(init.externalMicroPackages.first.import, isNull);
      expect(
        init.externalMicroPackages.last.import,
        'package:feature_posts/src/posts.kaisel.dart',
      );
    });

    test('should accept snake_case argument names', () {
      final init = parser.parseInit('''
@KaiselInit(route_class: 'Route', initial_route: 'HomeMount', external_micro_packages: [
  ExternalMicroPackage(FeatureShopKaiselModule),
])
void configureRouting() {}
''');

      expect(init!.routeClass, 'Route');
      expect(init.initialRoute, 'HomeMount');
      expect(init.externalMicroPackages, hasLength(1));
    });

    test('should ignore commented-out external micro packages', () {
      final init = parser.parseInit('''
@KaiselInit(
  externalMicroPackages: [
    // ExternalMicroPackage(LineCommentedKaiselModule),
    ExternalMicroPackage(FeatureShopKaiselModule),
    /* ExternalMicroPackage(BlockCommentedKaiselModule), */
  ],
)
void configureRouting() {}
''');

      expect(
        init!.externalMicroPackages.map((reference) => reference.module),
        ['FeatureShopKaiselModule'],
      );
    });

    test('should return null when the file declares no init', () {
      expect(parser.parseInit('class Nothing {}'), isNull);
    });
  });

  group('parseMicroPackage', () {
    test('should read module name, output and prefix', () {
      final microPackage = parser.parseMicroPackage(
        'lib/feature_shop.dart',
        '''
@KaiselMicroPackage(
  moduleName: 'FeatureShop',
  output: 'lib/src/shop.kaisel.dart',
  prefix: '/shop',
)
void configureFeatureShop() {}
''',
      );

      expect(microPackage, isNotNull);
      expect(microPackage!.moduleName, 'FeatureShop');
      expect(microPackage.output, 'lib/src/shop.kaisel.dart');
      expect(microPackage.prefix, '/shop');
      expect(microPackage.filePath, 'lib/feature_shop.dart');
    });

    test('should ignore a declaration without a module name', () {
      expect(
        parser.parseMicroPackage('lib/feature_shop.dart', '''
@KaiselMicroPackage(moduleName: '')
void configureFeatureShop() {}
'''),
        isNull,
      );
    });

    test('should return null when the file declares no micro-package', () {
      expect(parser.parseMicroPackage('lib/shop.dart', 'class Shop {}'), isNull);
    });
  });
}
