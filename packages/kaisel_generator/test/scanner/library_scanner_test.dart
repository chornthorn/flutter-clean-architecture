import 'package:kaisel_generator/src/model/init_info.dart';
import 'package:kaisel_generator/src/model/micro_package.dart';
import 'package:kaisel_generator/src/model/module_info.dart';
import 'package:kaisel_generator/src/parser/default_annotation_parser.dart';
import 'package:kaisel_generator/src/scanner/default_library_scanner.dart';
import 'package:kaisel_generator/src/spi/parser.dart';
import 'package:test/test.dart';

import '../support/temp_project.dart';

void main() {
  const scanner = DefaultLibraryScanner(parser: DefaultAnnotationParser());

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

    final scan = scanner.scan(project.directory('lib'));

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

    final scan = scanner.scan(project.directory('lib'));

    expect(scan.modules.map((module) => module.mountName), ['ShopMount']);
    expect(scan.filesScanned, 1);
  });

  test('should read the init entry point and the micro-package declarations', () {
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

    final scan = scanner.scan(project.directory('lib'));

    expect(scan.init, isNotNull);
    expect(scan.init!.externalMicroPackages.single.module, 'FeatureShopKaiselModule');
    expect(scan.microPackages.single.moduleName, 'FeatureShop');
    expect(scan.modules, isEmpty);
    expect(scan.filesParsed, 2);
  });

  test('should treat a missing lib directory as empty', () {
    final project = TempProject.create('scan_missing_lib');
    addTearDown(project.delete);

    final scan = scanner.scan(project.directory('lib'));

    expect(scan.modules, isEmpty);
    expect(scan.init, isNull);
    expect(scan.microPackages, isEmpty);
    expect(scan.filesScanned, 0);
  });

  test('should scan with the parser it was given', () {
    final project = TempProject.create('scan_custom_parser');
    addTearDown(project.delete);
    project.write('lib/shop_module.dart', '@KaiselModule(prefix: \'/\')\nclass X {}\n');

    final scanner = DefaultLibraryScanner(parser: _StubParser());
    final scan = scanner.scan(project.directory('lib'));

    expect(scan.modules.single.mountName, 'StubMount');
  });
}

class _StubParser implements AnnotationParser {
  @override
  void close() {}

  @override
  List<ModuleInfo> parseModules(String filePath, String source) => [
        ModuleInfo(
          className: 'X',
          routeType: 'XRoute',
          mountName: 'StubMount',
          codecName: 'XRouteCodec',
          filePath: filePath,
        ),
      ];

  @override
  InitInfo? parseInit(String source) => null;

  @override
  MicroPackageDeclaration? parseMicroPackage(String filePath, String source) => null;
}
