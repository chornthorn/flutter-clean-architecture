import 'package:kaisel_generator/src/service/generation.dart';
import 'package:test/test.dart';

import '../support/temp_project.dart';

/// What one run resolves before anything is generated: where the sources are,
/// where the output goes, and what the package is called.
void main() {
  test('should resolve the project from the root it is given', () {
    final project = TempProject.create('run_paths');
    addTearDown(project.delete);
    project.write('pubspec.yaml', 'name: demo\n');
    project.write('lib/features/home/home_module.dart', '''
@KaiselModule(isInitial: true)
class HomeRouterModule extends RouteModule<HomeRoute> {
  const HomeRouterModule();
}
''');

    final run = GenerationRun(root: project.root);

    expect(run.project.root, project.root);
    expect(run.project.libDir, project.path('lib'));
    expect(run.project.outputPath, project.path('lib/app/app_modules.g.dart'));
    expect(run.project.packageName, 'demo');
    expect(run.scan.modules.map((module) => module.mountName), ['HomeMount']);
    expect(run.request.modules.single.className, 'HomeRouterModule');
  });

  test('should let kaisel.yaml decide the scan directory and the output', () {
    final project = TempProject.create('run_config');
    addTearDown(project.delete);
    project.write('pubspec.yaml', 'name: demo\n');
    project.write(
      'kaisel.yaml',
      'output: lib/gen/registry.g.dart\nlib_dir: src\n',
    );
    project.write('src/features/home/home_module.dart', '''
@KaiselModule()
class HomeRouterModule extends RouteModule<HomeRoute> {
  const HomeRouterModule();
}
''');
    project.write('lib/features/shop/shop_module.dart', '''
@KaiselModule()
class ShopRouterModule extends RouteModule<ShopRoute> {
  const ShopRouterModule();
}
''');

    final run = GenerationRun(root: project.root);

    expect(run.project.libDir, project.path('src'));
    expect(run.project.outputPath, project.path('lib/gen/registry.g.dart'));
    // The scan read the directory the config names, not `lib/`.
    expect(run.scan.modules.map((module) => module.mountName), ['HomeMount']);
  });

  test('should let the entry point decide the output when no config does', () {
    final project = TempProject.create('run_init');
    addTearDown(project.delete);
    project.write('pubspec.yaml', 'name: demo\n');
    project.write('lib/app/app.dart', '''
@KaiselInit(output: 'lib/other/registry.g.dart')
void configureRouting() {}
''');

    final run = GenerationRun(root: project.root);

    expect(run.project.outputPath, project.path('lib/other/registry.g.dart'));
    expect(run.request.isHost, isTrue);
    expect(run.request.init, isNotNull);
  });

  test('should resolve once, however many getters are read', () {
    final project = TempProject.create('run_once');
    addTearDown(project.delete);
    project.write('pubspec.yaml', 'name: demo\n');
    project.write('lib/features/home/home_module.dart', '''
@KaiselModule()
class HomeRouterModule extends RouteModule<HomeRoute> {
  const HomeRouterModule();
}
''');

    final run = GenerationRun(root: project.root);

    expect(identical(run.project, run.project), isTrue);
    expect(identical(run.scan, run.scan), isTrue);
    expect(identical(run.request, run.request), isTrue);
    expect(run.scan.filesScanned, 1);
  });
}
