import 'package:kaisel_generator/src/model/generation_result.dart';
import 'package:kaisel_generator/src/model/module_info.dart';
import 'package:test/test.dart';

void main() {
  group('sortModules', () {
    test('should put the initial module first and sort the rest by mount name', () {
      final sorted = sortModules([
        _module(mountName: 'ShopMount', prefix: '/shop', filePath: '/app/lib/shop_module.dart'),
        _module(mountName: 'PostsMount', prefix: '/posts', filePath: '/app/lib/posts_module.dart'),
        _module(
          mountName: 'HomeMount',
          routeType: 'HomeRoute',
          filePath: '/app/lib/home_module.dart',
          isInitial: true,
        ),
      ]);

      expect(
        sorted.map((module) => module.mountName),
        ['HomeMount', 'PostsMount', 'ShopMount'],
      );
    });

    test('should not reorder the list it was given', () {
      final modules = [
        _module(mountName: 'ShopMount', prefix: '/shop', filePath: '/app/lib/shop_module.dart'),
        _module(
          mountName: 'HomeMount',
          routeType: 'HomeRoute',
          filePath: '/app/lib/home_module.dart',
          isInitial: true,
        ),
      ];

      sortModules(modules);

      expect(modules.map((module) => module.mountName), ['ShopMount', 'HomeMount']);
    });
  });

  group('validateMountNames', () {
    test('should reject a mount the host declares twice', () {
      expect(
        () => validateMountNames([
          _module(mountName: 'ShopMount', prefix: '/shop', filePath: '/app/lib/a.dart'),
          _module(mountName: 'ShopMount', prefix: '/shop/v2', filePath: '/app/lib/b.dart'),
        ]),
        throwsA(
          isA<KaiselGenerationException>().having(
            (error) => error.message,
            'message',
            contains('declared twice'),
          ),
        ),
      );
    });

    test('should accept distinct mount names', () {
      expect(
        () => validateMountNames([
          _module(mountName: 'ShopMount', prefix: '/shop', filePath: '/app/lib/a.dart'),
          _module(mountName: 'HomeMount', routeType: 'HomeRoute', filePath: '/app/lib/b.dart'),
        ]),
        returnsNormally,
      );
    });
  });
}

ModuleInfo _module({
  String routeType = 'ShopRoute',
  required String mountName,
  required String filePath,
  String? prefix,
  bool isInitial = false,
}) =>
    ModuleInfo(
      className: 'ShopRouterModule',
      routeType: routeType,
      mountName: mountName,
      codecName: '${routeType}Codec',
      filePath: filePath,
      prefix: prefix,
      isInitial: isInitial,
    );
