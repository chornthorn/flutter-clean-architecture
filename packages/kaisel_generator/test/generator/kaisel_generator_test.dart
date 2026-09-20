import 'package:kaisel_generator/kaisel_generator.dart';
import 'package:test/test.dart';

import '../support/temp_project.dart';

/// End-to-end coverage of the micro-package workflow: a feature package
/// generates its own manifest, and a host app composes it through
/// `@KaiselInit(externalMicroPackages: [...])`.
void main() {
  final generator = const KaiselGenerator();

  test('should generate the manifest contract of a standalone micro-package',
      () async {
    final repo = TempProject.create('standalone');
    addTearDown(repo.delete);
    final featureShop = _writeFeatureShopFixture(repo);

    final result = await generator.generate(root: featureShop, force: true);

    expect(result.success, isTrue, reason: result.error);
    expect(result.modulesCount, 1);
    expect(result.outputPath,
        '${repo.root}/feature_shop/lib/feature_shop.kaisel.dart');

    final manifest = repo.read('feature_shop/lib/feature_shop.kaisel.dart');
    expect(manifest,
        contains("import 'package:kaisel_generator/micro_mount.dart';"));
    expect(manifest, contains('abstract final class FeatureShopKaiselModule'));
    // The mount is a typed declaration: no name for a host to dispatch on.
    expect(manifest,
        contains('static const KaiselMicroMount<i1.ShopRoute> shopMount ='));
    expect(manifest, contains('    module: i1.ShopRouterModule(),'));
    expect(manifest, contains('    codec: i1.ShopRouteCodec(),'));
    expect(manifest, contains("    prefix: '/shop/products',"));
    expect(manifest, isNot(contains('mountNames')));

    // A micro-package never writes a host registry.
    expect(repo.exists('feature_shop/lib/app/app_modules.g.dart'), isFalse);
  });

  test('should compose an external micro-package into the host', () async {
    final repo = TempProject.create('host');
    addTearDown(repo.delete);
    _writeFeatureShopFixture(repo);
    _writeHostApp(repo, withPackageConfig: true);

    final feature =
        await generator.generate(root: repo.path('feature_shop'), force: true);
    expect(feature.success, isTrue, reason: feature.error);

    final host = await generator.generate(root: repo.path('app'), force: true);
    expect(host.success, isTrue, reason: host.error);

    final registry = repo.read('app/lib/app/app_modules.g.dart');
    expect(registry,
        contains("import 'package:kaisel_generator/micro_mount.dart';"));
    expect(
        registry,
        contains(
            "import 'package:feature_shop/feature_shop.kaisel.dart' as _mp1;"));
    expect(registry, contains('final class ShopMount extends AppRoute'));
    expect(
        registry,
        contains(
            'ShopMount() => _mp1.FeatureShopKaiselModule.shopMount.page,'));
    expect(registry,
        contains('ShopMount() => _mp1.FeatureShopKaiselModule.shopMount.url,'));
    expect(
      registry,
      contains(
          '_mp1.FeatureShopKaiselModule.shopMount.moduleMount(const ShopMount()),'),
    );
    expect(
        registry, contains('const AppRoute kInitialAppRoute = HomeMount();'));
  });

  test('should compose a registered manifest without touching the package',
      () async {
    final repo = TempProject.create('registered_external');
    addTearDown(repo.delete);
    final app = _writeRegisteredProfileFixture(repo, packageInsideApp: true);

    // The package's own run writes its manifest...
    final packageRun = await generator.generate(
      root: repo.path('app/features/profile'),
      force: true,
    );
    expect(packageRun.success, isTrue, reason: packageRun.error);
    final manifest = repo.read('app/features/profile/lib/profile.kaisel.dart');

    // ...and the host composes exactly that file.
    final host = await generator.generate(root: app, force: true);
    expect(host.success, isTrue, reason: host.error);

    final registry = repo.read('app/lib/app/app_modules.g.dart');
    expect(
      registry,
      contains("import 'package:profile/profile.kaisel.dart' as _mp1;"),
      reason: registry,
    );
    expect(
        registry,
        contains(
            'ProfileMount() => _mp1.ProfileKaiselModule.profileMount.page,'));
    expect(
      '_mp1.ProfileKaiselModule.profileMount.moduleMount(const ProfileMount())'
          .allMatches(registry)
          .length,
      1,
      reason: 'package mounted twice:\n$registry',
    );
    expect(registry, isNot(contains('_mp2')),
        reason: 'package composed twice:\n$registry');

    // Regenerating an unchanged manifest does not rewrite it.
    expect(repo.read('app/features/profile/lib/profile.kaisel.dart'), manifest);
  });

  test(
      'should generate the manifest of an in-project package from the host run',
      () async {
    final repo = TempProject.create('registered_in_project');
    addTearDown(repo.delete);
    final app = _writeRegisteredProfileFixture(repo, packageInsideApp: true);
    expect(
        repo.exists('app/features/profile/lib/profile.kaisel.dart'), isFalse);

    final result = await generator.generate(root: app, force: true);

    expect(result.success, isTrue, reason: result.error);
    final manifest = repo.read('app/features/profile/lib/profile.kaisel.dart');
    expect(manifest, contains('abstract final class ProfileKaiselModule'));
    expect(
        manifest,
        contains(
            'static const KaiselMicroMount<i1.ProfileRoute> profileMount ='));
    // Imports inside the manifest are package URIs too, not relative paths.
    expect(
      manifest,
      contains("import 'package:profile/profile_module.dart' as i1;"),
      reason: manifest,
    );

    final registry = repo.read('app/lib/app/app_modules.g.dart');
    expect(registry,
        contains("import 'package:profile/profile.kaisel.dart' as _mp1;"));
    expect(
        registry,
        contains(
            'ProfileMount() => _mp1.ProfileKaiselModule.profileMount.page,'));
  });

  test('should refresh a stale in-project manifest from the package sources',
      () async {
    final repo = TempProject.create('refresh_manifest');
    addTearDown(repo.delete);
    final app = _writeRegisteredProfileFixture(repo, packageInsideApp: true);
    repo.write(
        'app/features/profile/lib/profile.kaisel.dart', '// stale manifest\n');

    final result = await generator.generate(root: app, force: true);

    expect(result.success, isTrue, reason: result.error);
    final manifest = repo.read('app/features/profile/lib/profile.kaisel.dart');
    expect(manifest, contains('abstract final class ProfileKaiselModule'));
    expect(
        manifest,
        contains(
            'static const KaiselMicroMount<i1.ProfileRoute> profileMount ='));
    expect(manifest,
        contains("import 'package:profile/profile_module.dart' as i1;"));
  });

  test('should insert the owner when a package mount takes a host name',
      () async {
    final repo = TempProject.create('owner_infix');
    addTearDown(repo.delete);
    final app = _writeRegisteredProfileFixture(repo, packageInsideApp: true);

    // The host declares its own `ShopMount`, and the package claims that name too.
    repo.write('app/lib/features/shop/shop_module.dart', _hostShopModule);
    repo.write(
      'app/features/profile/lib/profile_module.dart',
      _profileModule.replaceFirst(
          "mount: 'ProfileMount'", "mount: 'ShopMount'"),
    );

    final result = await generator.generate(root: app, force: true);

    expect(result.success, isTrue, reason: result.error);
    final registry = repo.read('app/lib/app/app_modules.g.dart');
    expect(
      'final class ShopMount extends AppRoute'.allMatches(registry).length,
      1,
      reason: registry,
    );
    expect(
      'final class ShopProfileMount extends AppRoute'
          .allMatches(registry)
          .length,
      1,
      reason: registry,
    );
    expect(
      registry,
      contains(
          'ShopProfileMount() => _mp1.ProfileKaiselModule.shopMount.page,'),
    );
    expect(
      registry,
      contains(
          '_mp1.ProfileKaiselModule.shopMount.moduleMount(const ShopProfileMount()),'),
    );
    expect(
        registry,
        contains(
            'ShopProfileMount() => _mp1.ProfileKaiselModule.shopMount.url,'));
  });

  test('should leave the registry to the caller that owns it', () async {
    final repo = TempProject.create('registry_return');
    addTearDown(repo.delete);
    final app = _writeRegisteredProfileFixture(repo, packageInsideApp: true);

    final result =
        await generator.generate(root: app, force: true, write: false);

    expect(result.success, isTrue, reason: result.error);
    final code = result.code;
    expect(code, isNotNull);
    expect(code, contains('final class ProfileMount extends AppRoute'));
    expect(code,
        contains("import 'package:profile/profile.kaisel.dart' as _mp1;"));
    // The caller (build_runner) owns the registry file...
    expect(repo.exists('app/lib/app/app_modules.g.dart'), isFalse);
    // ...but manifests live in other packages, so they are always written.
    expect(repo.exists('app/features/profile/lib/profile.kaisel.dart'), isTrue);
  });

  test('should not generate the manifest of a package outside the project',
      () async {
    final repo = TempProject.create('foreign_manifest');
    addTearDown(repo.delete);
    final app = _writeRegisteredProfileFixture(repo, packageInsideApp: false);

    final result = await generator.generate(root: app, force: true);

    expect(result.success, isFalse,
        reason: 'the host must not generate a foreign package');
    expect(result.error, contains('Generate it first'));
    expect(repo.exists('feature_profile/lib/profile.kaisel.dart'), isFalse);
  });

  test('should report an actionable error when the host has no pub get',
      () async {
    final repo = TempProject.create('missing_pub_get');
    addTearDown(repo.delete);
    _writeFeatureShopFixture(repo);
    _writeHostApp(repo, withPackageConfig: false);

    final feature =
        await generator.generate(root: repo.path('feature_shop'), force: true);
    expect(feature.success, isTrue, reason: feature.error);

    final host = await generator.generate(root: repo.path('app'), force: true);

    expect(host.success, isFalse);
    expect(host.error, contains('dart pub get'));
  });

  test('should report a duplicate host mount instead of dropping a route',
      () async {
    final repo = TempProject.create('duplicate_mount');
    addTearDown(repo.delete);
    final app = _writeRegisteredProfileFixture(repo, packageInsideApp: true);

    // Two host modules claim the same mount name.
    repo.write('app/lib/features/shop/shop_module.dart', _hostShopModule);
    repo.write(
      'app/lib/features/shop_v2/shop_v2_module.dart',
      _hostShopModule.replaceFirst("prefix: '/shop'", "prefix: '/shop/v2'"),
    );

    final result = await generator.generate(root: app, force: true);

    expect(result.success, isFalse);
    expect(result.error, contains('declared twice'));
  });
}

const _hostModule = '''
class HomeRoute extends KaiselRoute {
  const HomeRoute();
}

@KaiselModule(isInitial: true)
class HomeRouterModule extends RouteModule<HomeRoute> {
  const HomeRouterModule();
}
''';

const _hostShopModule = '''
class ShopRoute extends KaiselRoute {
  const ShopRoute();
}

@KaiselModule(prefix: '/shop')
class ShopRouterModule extends RouteModule<ShopRoute> {
  const ShopRouterModule();
}
''';

/// Writes `<repo>/feature_shop`, returning its root.
String _writeFeatureShopFixture(TempProject repo) {
  repo.write(
      'feature_shop/pubspec.yaml', 'name: feature_shop\nversion: 0.1.0\n');
  repo.write('feature_shop/lib/feature_shop.dart', '''

@KaiselMicroPackage(moduleName: 'FeatureShop', prefix: '/shop')
void configureFeatureShop() {}
''');
  repo.write('feature_shop/lib/src/shop_module.dart', '''
class ShopRoute extends KaiselRoute {
  const ShopRoute();
}

@KaiselModule(prefix: '/products')
class ShopRouterModule extends RouteModule<ShopRoute> {
  const ShopRouterModule();
}
''');
  return repo.path('feature_shop');
}

/// Writes `<repo>/app`, a host that registers `feature_shop`.
String _writeHostApp(TempProject repo, {required bool withPackageConfig}) {
  repo.write(
    'app/pubspec.yaml',
    'name: host_app\nversion: 0.1.0\ndependencies:\n  feature_shop:\n    path: ../feature_shop\n',
  );
  repo.write('app/lib/app/app.dart', '''

@KaiselInit(
  externalMicroPackages: [
    ExternalMicroPackage(FeatureShopKaiselModule),
  ],
)
void configureRouting() {}
''');
  repo.write('app/lib/app/home_module.dart', _hostModule);

  if (withPackageConfig) {
    repo.write(
      'app/.dart_tool/package_config.json',
      '''
{
  "configVersion": 2,
  "packages": [
    {"name": "host_app", "rootUri": "../", "packageUri": "lib/", "languageVersion": "3.0"},
    {"name": "feature_shop", "rootUri": "../../feature_shop", "packageUri": "lib/", "languageVersion": "3.0"}
  ]
}
''',
    );
  }

  return repo.path('app');
}

const _profileAnnotation = '''

@KaiselMicroPackage(moduleName: 'Profile')
void configureProfileModule() {}
''';

const _profileModule = '''
class ProfileRoute extends KaiselRoute {
  const ProfileRoute();
}

@KaiselModule(prefix: '/profile', mount: 'ProfileMount')
class ProfileRouterModule extends RouteModule<ProfileRoute> {
  const ProfileRouterModule();
}
''';

const _hostWithRegisteredProfile = '''
import 'package:profile/profile.kaisel.dart';

@KaiselInit(
  externalMicroPackages: [
    ExternalMicroPackage(ProfileKaiselModule),
  ],
)
void configureRouting() {}
''';

/// Writes `<repo>/app` depending on `profile`, either as a package inside the app
/// (`features/profile`, the reference app's layout) or outside it (a sibling
/// package the host can only compose).
String _writeRegisteredProfileFixture(
  TempProject repo, {
  required bool packageInsideApp,
}) {
  final profilePath =
      packageInsideApp ? 'features/profile' : '../feature_profile';

  repo.write(
    'app/pubspec.yaml',
    'name: flutter_x\nversion: 0.1.0\ndependencies:\n  profile:\n    path: $profilePath\n',
  );
  repo.write('app/lib/app/app.dart', _hostWithRegisteredProfile);
  repo.write('app/lib/features/home/home_module.dart', _hostModule);

  final profileRoot =
      packageInsideApp ? 'app/features/profile' : 'feature_profile';
  repo.write('$profileRoot/pubspec.yaml', 'name: profile\nversion: 0.1.0\n');
  repo.write('$profileRoot/lib/profile.dart', _profileAnnotation);
  repo.write('$profileRoot/lib/profile_module.dart', _profileModule);

  repo.write(
    'app/.dart_tool/package_config.json',
    '''
{
  "configVersion": 2,
  "packages": [
    {"name": "flutter_x", "rootUri": "../", "packageUri": "lib/", "languageVersion": "3.0"},
    {"name": "profile", "rootUri": "../$profilePath", "packageUri": "lib/", "languageVersion": "3.0"}
  ]
}
''',
  );

  return repo.path('app');
}
