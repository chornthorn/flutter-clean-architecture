import 'package:kaisel_generator/src/scanner/library_scanner.dart';
import 'package:test/test.dart';

import '../support/temp_project.dart';

void main() {
  const scanner = LibraryScanner();

  test('should scan modules and count the files it read', () {
    final project = TempProject.create('scan_modules');
    addTearDown(project.delete);
    project.write('lib/features/home/home_module.dart', '''
@KaiselModule(isInitial: true)
class HomeRouterModule extends RouteModule<HomeRoute> {
  const HomeRouterModule();
}
''');
    project.write('lib/features/shop/shop_module.dart', '''
@KaiselModule(prefix: '/shop')
class ShopRouterModule extends RouteModule<ShopRoute> {
  const ShopRouterModule();
}
''');
    project.write('lib/features/shop/shop_view.dart', 'class ShopView {}\n');

    final scan = scanner.scanModules(project.directory('lib'));

    expect(
      scan.modules.map((module) => module.mountName),
      ['HomeMount', 'ShopMount'],
    );
    expect(scan.filesScanned, 3);
    expect(scan.filesParsed, 2);
  });

  test('should skip generated sources', () {
    final project = TempProject.create('scan_generated');
    addTearDown(project.delete);
    project.write('lib/app/app_modules.g.dart', '''
@KaiselModule(prefix: '/generated')
class GeneratedRouterModule extends RouteModule<GeneratedRoute> {
  const GeneratedRouterModule();
}
''');
    project.write('lib/features/shop/shop_module.dart', '''
@KaiselModule(prefix: '/shop')
class ShopRouterModule extends RouteModule<ShopRoute> {
  const ShopRouterModule();
}
''');

    final scan = scanner.scanModules(project.directory('lib'));

    expect(scan.modules.map((module) => module.mountName), ['ShopMount']);
    expect(scan.filesScanned, 1);
  });

  test('should find the init entry point and the micro-package declarations', () {
    final project = TempProject.create('scan_annotations');
    addTearDown(project.delete);
    project.write('lib/app/app.dart', '''
@KaiselInit(externalMicroPackages: [ExternalMicroPackage(FeatureShopKaiselModule)])
void configureRouting() {}
''');
    project.write('lib/feature_shop.dart', '''
@KaiselMicroPackage(moduleName: 'FeatureShop', prefix: '/shop')
void configureFeatureShop() {}
''');

    final init = scanner.findInit(project.directory('lib'));
    final microPackages = scanner.findMicroPackages(project.directory('lib'));

    expect(init, isNotNull);
    expect(init!.externalMicroPackages.single.module, 'FeatureShopKaiselModule');
    expect(microPackages.single.moduleName, 'FeatureShop');
  });

  test('should treat a missing lib directory as empty', () {
    final project = TempProject.create('scan_missing_lib');
    addTearDown(project.delete);

    final scan = scanner.scanModules(project.directory('lib'));

    expect(scan.modules, isEmpty);
    expect(scan.filesScanned, 0);
    expect(scanner.findInit(project.directory('lib')), isNull);
  });
}
