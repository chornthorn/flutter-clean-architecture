import 'package:kaisel_generator/kaisel_generator.dart';
import 'package:test/test.dart';

import '../support/temp_project.dart';

/// Which generation serves a project: a host application gets the registry it
/// runs on, a package that declares `@KaiselMicroPackage` gets its manifest.
void main() {
  final generator = const KaiselGenerator();

  test('should write a manifest for a micro-package', () async {
    final project = TempProject.create('generation_micro');
    addTearDown(project.delete);
    project.write('pubspec.yaml', 'name: feature_shop\n');
    project.write('lib/feature_shop.dart', '''
@KaiselMicroPackage(moduleName: 'FeatureShop', prefix: '/shop')
void configureFeatureShop() {}
''');
    project.write('lib/shop_module.dart', '''
@KaiselModule(prefix: '/shop/products')
class ShopRouterModule extends RouteModule<ShopRoute> {
  const ShopRouterModule();
}
''');

    final result = await generator.generate(root: project.root, force: true);

    expect(result.success, isTrue, reason: result.error);
    expect(result.outputPath, project.path('lib/feature_shop.kaisel.dart'));
    expect(project.exists('lib/app/app_modules.g.dart'), isFalse);
    expect(
      project.read('lib/feature_shop.kaisel.dart'),
      contains('abstract final class FeatureShopKaiselModule'),
    );
  });

  test('should write a registry for a host, and no manifest', () async {
    final project = TempProject.create('generation_host');
    addTearDown(project.delete);
    project.write('pubspec.yaml', 'name: demo\n');
    project.write('lib/app/app.dart', '''
@KaiselInit()
void configureRouting() {}
''');
    project.write('lib/features/home/home_module.dart', '''
@KaiselModule(isInitial: true)
class HomeRouterModule extends RouteModule<HomeRoute> {
  const HomeRouterModule();
}
''');

    final result = await generator.generate(root: project.root, force: true);

    expect(result.success, isTrue, reason: result.error);
    expect(result.outputPath, project.path('lib/app/app_modules.g.dart'));
    expect(project.exists('lib/demo.kaisel.dart'), isFalse);
    expect(
      project.read('lib/app/app_modules.g.dart'),
      contains('final class HomeMount extends AppRoute'),
    );
  });
}
