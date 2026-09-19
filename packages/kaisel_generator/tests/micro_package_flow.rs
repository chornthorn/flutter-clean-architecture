//! End-to-end coverage of the micro-package workflow: a feature package
//! generates its own manifest, and a host app composes it through
//! `@KaiselInit(externalMicroPackages: [...])`.

use std::fs;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};

use kaisel_generator::{execute_generation, execute_generation_with, RegistryOutput};

const FEATURE_SHOP_PUBSPEC: &str = "name: feature_shop\nversion: 0.1.0\n";

const FEATURE_SHOP_ANNOTATION: &str = r#"
import 'package:kaisel_generator/kaisel_generator.dart';

@KaiselMicroPackage(moduleName: 'FeatureShop', prefix: '/shop')
void configureFeatureShop() {}
"#;

const FEATURE_SHOP_MODULE: &str = r#"
class ShopRoute extends KaiselRoute {
  const ShopRoute();
}

@KaiselModule(prefix: '/products')
class ShopRouterModule extends RouteModule<ShopRoute> {
  const ShopRouterModule();
}
"#;

const HOST_PUBSPEC: &str =
    "name: host_app\nversion: 0.1.0\ndependencies:\n  feature_shop:\n    path: ../feature_shop\n";

const HOST_INIT: &str = r#"
import 'package:kaisel_generator/kaisel_generator.dart';

@KaiselInit(
  externalMicroPackages: [
    ExternalMicroPackage(FeatureShopKaiselModule),
  ],
)
void configureRouting() {}
"#;

const HOST_MODULE: &str = r#"
class HomeRoute extends KaiselRoute {
  const HomeRoute();
}

@KaiselModule(isInitial: true)
class HomeRouterModule extends RouteModule<HomeRoute> {
  const HomeRouterModule();
}
"#;

fn temp_dir(label: &str) -> PathBuf {
    static COUNTER: AtomicU64 = AtomicU64::new(0);
    let unique = COUNTER.fetch_add(1, Ordering::Relaxed);
    let path = std::env::temp_dir().join(format!(
        "kaisel_flow_{label}_{}_{unique}",
        std::process::id()
    ));
    let _ = fs::remove_dir_all(&path);
    fs::create_dir_all(&path).unwrap();
    path
}

fn write_file(path: &Path, content: &str) {
    fs::create_dir_all(path.parent().unwrap()).unwrap();
    fs::write(path, content).unwrap();
}

/// Creates `<repo>/feature_shop` and `<repo>/app`, returning both roots.
fn write_fixture(repo: &Path, write_package_config: bool) -> (PathBuf, PathBuf) {
    let feature_shop = repo.join("feature_shop");
    write_file(&feature_shop.join("pubspec.yaml"), FEATURE_SHOP_PUBSPEC);
    write_file(
        &feature_shop.join("lib/feature_shop.dart"),
        FEATURE_SHOP_ANNOTATION,
    );
    write_file(
        &feature_shop.join("lib/src/shop_module.dart"),
        FEATURE_SHOP_MODULE,
    );

    let app = repo.join("app");
    write_file(&app.join("pubspec.yaml"), HOST_PUBSPEC);
    write_file(&app.join("lib/app/app.dart"), HOST_INIT);
    write_file(&app.join("lib/app/home_module.dart"), HOST_MODULE);

    if write_package_config {
        let package_config = format!(
            r#"{{"configVersion":2,"packages":[
  {{"name":"host_app","rootUri":"../","packageUri":"lib/","languageVersion":"3.0"}},
  {{"name":"feature_shop","rootUri":"file://{}","packageUri":"lib/","languageVersion":"3.0"}}
]}}"#,
            feature_shop.display()
        );
        write_file(&app.join(".dart_tool/package_config.json"), &package_config);
    }

    (feature_shop, app)
}

#[test]
fn standalone_micro_package_generates_manifest_contract() {
    let repo = temp_dir("standalone");
    let (feature_shop, _app) = write_fixture(&repo, false);

    let result = execute_generation(Some(&feature_shop), None, None, true);
    assert!(result.success, "generation failed: {:?}", result.error);

    let manifest_path = feature_shop.join("lib/feature_shop.kaisel.dart");
    let manifest = fs::read_to_string(&manifest_path).expect("manifest should be generated");
    assert!(manifest.contains("import 'package:kaisel_generator/micro_mount.dart';"));
    assert!(manifest.contains("abstract final class FeatureShopKaiselModule"));
    // The mount is a typed declaration: no name for a host to dispatch on.
    assert!(manifest.contains("static const KaiselMicroMount<i1.ShopRoute> shopMount ="));
    assert!(manifest.contains("    module: i1.ShopRouterModule(),"));
    assert!(manifest.contains("    codec: i1.ShopRouteCodec(),"));
    assert!(manifest.contains("    prefix: '/shop/products',"));
    assert!(!manifest.contains("mountNames"));

    // A micro-package never writes a host registry.
    assert!(!feature_shop.join("lib/app/app_modules.g.dart").exists());

    let _ = fs::remove_dir_all(&repo);
}

#[test]
fn host_app_composes_external_micro_package() {
    let repo = temp_dir("host");
    let (feature_shop, app) = write_fixture(&repo, true);

    let feature_result = execute_generation(Some(&feature_shop), None, None, true);
    assert!(
        feature_result.success,
        "micro-package generation failed: {:?}",
        feature_result.error
    );

    let host_result = execute_generation(Some(&app), None, None, true);
    assert!(
        host_result.success,
        "host generation failed: {:?}",
        host_result.error
    );

    let host = fs::read_to_string(app.join("lib/app/app_modules.g.dart"))
        .expect("host registry should be generated");

    assert!(host.contains("import 'package:kaisel_generator/micro_mount.dart';"));
    assert!(host.contains("import 'package:feature_shop/feature_shop.kaisel.dart' as _mp1;"));
    assert!(host.contains("final class ShopMount extends AppRoute"));
    // Pages and URLs are delegated to the package's declaration...
    assert!(host.contains("ShopMount() => _mp1.FeatureShopKaiselModule.shopMount.page,"));
    assert!(host.contains("ShopMount() => _mp1.FeatureShopKaiselModule.shopMount.url,"));
    // ...and the host binds it to its own marker instance instead of a name.
    assert!(host.contains(
        "_mp1.FeatureShopKaiselModule.shopMount.moduleMount(const ShopMount()),"
    ));
    assert!(!host.contains("_createExternalMountRoute"));
    assert!(host.contains("const AppRoute kInitialAppRoute = HomeMount();"));

    let _ = fs::remove_dir_all(&repo);
}

const PROFILE_PUBSPEC: &str = "name: profile\nversion: 0.1.0\n";

const PROFILE_ANNOTATION: &str = r#"
import 'package:kaisel_generator/kaisel_generator.dart';

@KaiselMicroPackage(moduleName: 'Profile')
void configureProfileModule() {}
"#;

const PROFILE_MODULE: &str = r#"
class ProfileRoute extends KaiselRoute {
  const ProfileRoute();
}

@KaiselModule(prefix: '/profile', mount: 'ProfileMount')
class ProfileRouterModule extends RouteModule<ProfileRoute> {
  const ProfileRouterModule();
}
"#;

const HOST_WITH_REGISTERED_PROFILE: &str = r#"
import 'package:kaisel_generator/kaisel_generator.dart';
import 'package:profile/profile.kaisel.dart';

@KaiselInit(
  externalMicroPackages: [
    ExternalMicroPackage(ProfileKaiselModule),
  ],
)
void configureRouting() {}
"#;

const HOST_SHOP_MODULE: &str = r#"
class ShopRoute extends KaiselRoute {
  const ShopRoute();
}

@KaiselModule(prefix: '/shop')
class ShopRouterModule extends RouteModule<ShopRoute> {
  const ShopRouterModule();
}
"#;

/// Creates a host app that depends on `profile`, either as a package inside the
/// app (`features/profile`, the reference app's layout) or outside it (a sibling
/// package the host can only compose).
fn write_registered_profile_fixture(repo: &Path, package_inside_app: bool) -> PathBuf {
    let app = repo.join("app");
    let profile = if package_inside_app {
        app.join("features/profile")
    } else {
        repo.join("feature_profile")
    };
    let profile_path = if package_inside_app {
        "features/profile"
    } else {
        "../feature_profile"
    };

    write_file(
        &app.join("pubspec.yaml"),
        &format!(
            "name: flutter_x\nversion: 0.1.0\ndependencies:\n  profile:\n    path: {profile_path}\n"
        ),
    );
    write_file(&app.join("lib/app/app.dart"), HOST_WITH_REGISTERED_PROFILE);
    write_file(&app.join("lib/features/home/home_module.dart"), HOST_MODULE);

    write_file(&profile.join("pubspec.yaml"), PROFILE_PUBSPEC);
    write_file(&profile.join("lib/profile.dart"), PROFILE_ANNOTATION);
    write_file(&profile.join("lib/profile_module.dart"), PROFILE_MODULE);

    let package_config = format!(
        r#"{{"configVersion":2,"packages":[
  {{"name":"flutter_x","rootUri":"../","packageUri":"lib/","languageVersion":"3.0"}},
  {{"name":"profile","rootUri":"file://{}","packageUri":"lib/","languageVersion":"3.0"}}
]}}"#,
        profile.display()
    );
    write_file(&app.join(".dart_tool/package_config.json"), &package_config);

    app
}

#[test]
fn host_composes_registered_manifest_without_touching_the_package() {
    let repo = temp_dir("registered_external");
    let app = write_registered_profile_fixture(&repo, true);
    let manifest_path = app.join("features/profile/lib/profile.kaisel.dart");

    // The package's own run writes its manifest...
    let package_result = execute_generation(Some(&app.join("features/profile")), None, None, true);
    assert!(
        package_result.success,
        "micro-package generation failed: {:?}",
        package_result.error
    );
    let manifest = fs::read_to_string(&manifest_path).expect("manifest should be generated");

    // ...and the host only composes it.
    let result = execute_generation(Some(&app), None, None, true);
    assert!(result.success, "host generation failed: {:?}", result.error);

    let host = fs::read_to_string(app.join("lib/app/app_modules.g.dart")).unwrap();
    assert!(
        host.contains("import 'package:profile/profile.kaisel.dart' as _mp1;"),
        "explicit import was not used:\n{host}"
    );
    assert!(host.contains(
        "ProfileMount() => _mp1.ProfileKaiselModule.profileMount.page,"
    ));
    assert_eq!(
        host
            .matches("_mp1.ProfileKaiselModule.profileMount.moduleMount(const ProfileMount())")
            .count(),
        1,
        "package mounted twice:\n{host}"
    );
    assert!(!host.contains("_mp2"), "package composed twice:\n{host}");

    // An existing manifest is composed as-is, never rewritten by the host.
    assert_eq!(fs::read_to_string(&manifest_path).unwrap(), manifest);

    let _ = fs::remove_dir_all(&repo);
}

#[test]
fn registering_an_in_project_package_generates_its_manifest() {
    // The whole point: the app author writes the registration and runs the
    // generator once. The host reaches the registered package's sources itself.
    let repo = temp_dir("registered_in_project");
    let app = write_registered_profile_fixture(&repo, true);
    let manifest_path = app.join("features/profile/lib/profile.kaisel.dart");
    assert!(!manifest_path.exists());

    let result = execute_generation(Some(&app), None, None, true);
    assert!(result.success, "host generation failed: {:?}", result.error);

    let manifest = fs::read_to_string(&manifest_path).expect("host should write the manifest");
    assert!(manifest.contains("abstract final class ProfileKaiselModule"));
    assert!(manifest.contains("static const KaiselMicroMount<i1.ProfileRoute> profileMount ="));
    // Imports inside the manifest are package URIs too, not relative paths.
    assert!(
        manifest.contains("import 'package:profile/profile_module.dart' as i1;"),
        "unexpected imports:\n{manifest}"
    );

    let host = fs::read_to_string(app.join("lib/app/app_modules.g.dart")).unwrap();
    assert!(host.contains("import 'package:profile/profile.kaisel.dart' as _mp1;"));
    assert!(host.contains("ProfileMount() => _mp1.ProfileKaiselModule.profileMount.page,"));

    let _ = fs::remove_dir_all(&repo);
}

#[test]
fn in_project_manifest_is_refreshed_from_the_package() {
    let repo = temp_dir("refresh_manifest");
    let app = write_registered_profile_fixture(&repo, true);
    let manifest_path = app.join("features/profile/lib/profile.kaisel.dart");

    // Whatever a stale manifest says, the host's run rewrites it from the
    // package's current sources (which is also what picks up new routes).
    write_file(&manifest_path, "// stale manifest\n");

    let result = execute_generation(Some(&app), None, None, true);
    assert!(result.success, "host generation failed: {:?}", result.error);

    let manifest = fs::read_to_string(&manifest_path).unwrap();
    assert!(manifest.contains("abstract final class ProfileKaiselModule"));
    assert!(manifest.contains(
        "static const KaiselMicroMount<i1.ProfileRoute> profileMount ="
    ));
    assert!(manifest.contains("import 'package:profile/profile_module.dart' as i1;"));

    let _ = fs::remove_dir_all(&repo);
}

#[test]
fn package_mount_on_a_host_name_gets_the_owner_inserted() {
    let repo = temp_dir("owner_infix");
    let app = write_registered_profile_fixture(&repo, true);

    // The host declares its own `ShopMount`, and the package claims that name too.
    write_file(
        &app.join("lib/features/shop/shop_module.dart"),
        HOST_SHOP_MODULE,
    );
    write_file(
        &app.join("features/profile/lib/profile_module.dart"),
        &PROFILE_MODULE.replace("mount: 'ProfileMount'", "mount: 'ShopMount'"),
    );

    let result = execute_generation(Some(&app), None, None, true);
    assert!(result.success, "host generation failed: {:?}", result.error);
    let host = fs::read_to_string(app.join("lib/app/app_modules.g.dart")).unwrap();

    // The package's mount carries its owner between feature and `Mount`; the
    // host's own name is left exactly as it was.
    assert_eq!(host.matches("final class ShopMount extends AppRoute").count(), 1);
    assert_eq!(
        host.matches("final class ShopProfileMount extends AppRoute").count(),
        1
    );
    assert!(
        host.contains("ShopProfileMount() => _mp1.ProfileKaiselModule.shopMount.page,"),
        "{host}"
    );
    assert!(host.contains(
        "_mp1.ProfileKaiselModule.shopMount.moduleMount(const ShopProfileMount()),"
    ));
    assert!(host.contains("ShopProfileMount() => _mp1.ProfileKaiselModule.shopMount.url,"));

    let _ = fs::remove_dir_all(&repo);
}

#[test]
fn returning_the_registry_leaves_that_file_to_the_caller() {
    let repo = temp_dir("registry_return");
    let app = write_registered_profile_fixture(&repo, true);
    let registry = app.join("lib/app/app_modules.g.dart");
    let manifest = app.join("features/profile/lib/profile.kaisel.dart");

    let result = execute_generation_with(Some(&app), None, None, true, RegistryOutput::Return);
    assert!(result.success, "generation failed: {:?}", result.error);

    let code = result.code.expect("the registry source should come back");
    assert!(code.contains("final class ProfileMount extends AppRoute"));
    assert!(code.contains("import 'package:profile/profile.kaisel.dart' as _mp1;"));
    // The caller (build_runner) owns the registry file...
    assert!(!registry.exists(), "the registry must be left to the caller");
    // ...but manifests live in other packages, so they are always written.
    assert!(
        manifest.exists(),
        "package manifests must exist for the registry to compile"
    );

    let _ = fs::remove_dir_all(&repo);
}

#[test]
fn host_does_not_generate_a_foreign_package_manifest() {
    let repo = temp_dir("foreign_manifest_missing");
    let app = write_registered_profile_fixture(&repo, false);
    let foreign_manifest = repo.join("feature_profile/lib/profile.kaisel.dart");

    let result = execute_generation(Some(&app), None, None, true);
    assert!(
        !result.success,
        "the host must not generate a package outside its own project"
    );
    let error = result.error.unwrap_or_default();
    assert!(
        error.contains("Generate it first"),
        "unexpected error: {error}"
    );
    assert!(!foreign_manifest.exists());

    let _ = fs::remove_dir_all(&repo);
}

#[test]
fn host_app_without_pub_get_reports_actionable_error() {
    let repo = temp_dir("missing_pub_get");
    let (feature_shop, app) = write_fixture(&repo, false);

    let feature_result = execute_generation(Some(&feature_shop), None, None, true);
    assert!(feature_result.success, "micro-package generation failed");

    let host_result = execute_generation(Some(&app), None, None, true);
    assert!(
        !host_result.success,
        "host generation should fail without package_config.json"
    );
    let error = host_result.error.unwrap_or_default();
    assert!(error.contains("dart pub get"), "unexpected error: {error}");

    let _ = fs::remove_dir_all(&repo);
}
