use std::collections::HashSet;
use std::fs;
use std::path::{Path, PathBuf};
use std::time::Instant;

use serde::{Deserialize, Serialize};

use crate::generator::{generate_dart_code, generate_micro_package_code, MicroPackageInfo};
use crate::micro_package::{
    extract_micro_package_manifest, infer_import_uri, resolve_import_file,
    resolve_package_lib_dir, to_pascal_case,
};
use crate::parser::{
    extract_init_metadata, extract_micro_package_metadata, ExternalMicroPackageRef, InitMetadata,
    MicroPackageMetadata, ModuleMetadata,
};
use crate::scanner::{scan_and_extract, IncrementalCache};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GenerationResult {
    pub success: bool,
    pub error: Option<String>,
    pub files_scanned: usize,
    pub files_parsed: usize,
    pub modules_count: usize,
    pub elapsed_us: u128,
    pub output_path: Option<String>,
}

fn failure(
    error: String,
    start: Instant,
    files_scanned: usize,
    files_parsed: usize,
    modules_count: usize,
) -> GenerationResult {
    GenerationResult {
        success: false,
        error: Some(error),
        files_scanned,
        files_parsed,
        modules_count,
        elapsed_us: start.elapsed().as_micros(),
        output_path: None,
    }
}

#[derive(Debug, Default)]
pub struct KaiselYamlConfig {
    pub output: Option<String>,
    pub route_class: Option<String>,
    pub initial_route: Option<String>,
    pub lib_dir: Option<String>,
}

pub fn parse_kaisel_yaml(path: &Path) -> Option<KaiselYamlConfig> {
    let content = fs::read_to_string(path).ok()?;
    let mut config = KaiselYamlConfig::default();

    for line in content.lines() {
        let trimmed = line.trim();
        if trimmed.starts_with('#') || trimmed.is_empty() {
            continue;
        }
        if let Some((key, val)) = trimmed.split_once(':') {
            let key = key.trim();
            let val = val.trim().trim_matches('\'').trim_matches('"');
            match key {
                "output" => config.output = Some(val.to_string()),
                "route_class" => config.route_class = Some(val.to_string()),
                "initial_route" => config.initial_route = Some(val.to_string()),
                "lib_dir" => config.lib_dir = Some(val.to_string()),
                _ => {}
            }
        }
    }

    Some(config)
}

/// Reads the `name:` field of a package's `pubspec.yaml`.
pub fn parse_pubspec_package_name(package_root: &Path) -> Option<String> {
    let content = fs::read_to_string(package_root.join("pubspec.yaml")).ok()?;
    for line in content.lines() {
        if let Some(value) = line.strip_prefix("name:") {
            let value = value.trim().trim_matches('\'').trim_matches('"');
            if !value.is_empty() {
                return Some(value.to_string());
            }
        }
    }
    None
}

pub fn find_project_root(start: &Path) -> Option<PathBuf> {
    let mut current = start.to_path_buf();
    loop {
        if current.join("pubspec.yaml").exists() {
            return Some(current);
        }
        if !current.pop() {
            break;
        }
    }
    None
}

pub fn find_init_in_lib(lib_dir: &Path) -> Option<InitMetadata> {
    for entry in walkdir::WalkDir::new(lib_dir).into_iter().filter_map(|e| e.ok()) {
        let path = entry.path();
        if path.extension().is_some_and(|ext| ext == "dart") {
            if let Ok(content) = fs::read_to_string(path) {
                if content.contains("KaiselInit") {
                    if let Some(init_meta) = extract_init_metadata(&content) {
                        return Some(init_meta);
                    }
                }
            }
        }
    }
    None
}

pub fn find_micro_packages_in_lib(lib_dir: &Path) -> Vec<MicroPackageMetadata> {
    let mut result = Vec::new();
    for entry in walkdir::WalkDir::new(lib_dir).into_iter().filter_map(|e| e.ok()) {
        let path = entry.path();
        if path.extension().is_some_and(|ext| ext == "dart") {
            if let Ok(content) = fs::read_to_string(path) {
                if content.contains("KaiselMicroPackage") {
                    if let Some(mp_meta) = extract_micro_package_metadata(path, &content) {
                        result.push(mp_meta);
                    }
                }
            }
        }
    }
    result
}

fn sort_modules(modules: &mut [ModuleMetadata]) {
    modules.sort_by(|a, b| {
        b.is_initial
            .cmp(&a.is_initial)
            .then_with(|| a.mount_name.cmp(&b.mount_name))
    });
}

fn write_if_changed(path: &Path, content: &str) -> Result<(), String> {
    if fs::read_to_string(path).is_ok_and(|existing| existing == content) {
        return Ok(());
    }
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)
            .map_err(|e| format!("Failed to create directory `{}`: {e}", parent.display()))?;
    }
    fs::write(path, content).map_err(|e| format!("Failed to write `{}`: {e}", path.display()))
}

/// Resolves `ExternalMicroPackage(...)` entries declared on `@KaiselInit` to
/// generated manifests inside dependency packages.
///
/// A registered package that lives inside this project is generated here —
/// registering it is the only step the app writes. Everything outside the project
/// (a hosted or sibling-repo dependency) must generate its own manifest, because
/// its sources are not this project's to write.
fn resolve_external_micro_packages(
    root: &Path,
    output_dir: &Path,
    references: &[ExternalMicroPackageRef],
    cache: &IncrementalCache,
    force: bool,
) -> Result<Vec<MicroPackageInfo>, String> {
    let mut resolved: Vec<MicroPackageInfo> = Vec::new();

    for reference in references {
        if resolved
            .iter()
            .any(|existing| existing.class_name == reference.module)
        {
            continue;
        }

        let import_uri = match &reference.import {
            Some(import) => import.clone(),
            None => infer_import_uri(&reference.module).ok_or_else(|| {
                format!(
                    "Cannot infer the import URI for `ExternalMicroPackage({})`. Pass `import: 'package:<package>/<file>.kaisel.dart'` explicitly.",
                    reference.module
                )
            })?,
        };

        let manifest_path = resolve_import_file(root, output_dir, &import_uri)?;

        // A registered package inside this project is generated here on every run.
        // Write-if-changed keeps its manifest current — new routes, changed
        // prefixes, a different import style — without churning the file.
        if let Some(package_lib) = package_lib_dir_within_project(root, &import_uri)? {
            ensure_package_manifest(&package_lib, &manifest_path, cache, force)?;
        }

        let source = fs::read_to_string(&manifest_path).map_err(|e| {
            format!(
                "Micro-package `{}` could not be read at `{}`: {e}. Generate it first (`dart run kaisel_generator` in that package) and run `dart pub get` in the host app.",
                reference.module,
                manifest_path.display()
            )
        })?;
        let manifest = extract_micro_package_manifest(&source).ok_or_else(|| {
            format!(
                "`{}` is not a micro-package manifest written by a compatible kaisel_generator (no `KaiselModule` registry). Regenerate it.",
                manifest_path.display()
            )
        })?;

        if manifest.class_name != reference.module {
            return Err(format!(
                "`{}` declares the registry `{}`, but the host registers `{}`. Register the class the package generates.",
                manifest_path.display(),
                manifest.class_name,
                reference.module
            ));
        }

        resolved.push(MicroPackageInfo {
            class_name: reference.module.clone(),
            import_uri,
            slots: manifest.slots,
        });
    }

    Ok(resolved)
}

/// The `lib/` directory of the package an import URI belongs to, when that
/// package lives inside the host project.
fn package_lib_dir_within_project(root: &Path, import_uri: &str) -> Result<Option<PathBuf>, String> {
    let Some(rest) = import_uri.strip_prefix("package:") else {
        return Ok(None);
    };
    let Some((package, _)) = rest.split_once('/') else {
        return Ok(None);
    };

    let lib_dir = resolve_package_lib_dir(root, package)?;
    Ok(lib_dir.starts_with(root).then_some(lib_dir))
}

/// Generates a registered in-project package's manifest, so registering it is the
/// only step the app author writes.
fn ensure_package_manifest(
    package_lib: &Path,
    manifest_path: &Path,
    cache: &IncrementalCache,
    force: bool,
) -> Result<(), String> {
    let package_root = package_lib.parent().unwrap_or(package_lib);
    let scan = scan_and_extract(package_lib, cache, force);
    if scan.modules.is_empty() {
        return Err(format!(
            "`{}` is registered as a micro-package but declares no `@KaiselModule` in `{}`.",
            package_root.display(),
            package_lib.display()
        ));
    }

    let annotations = find_micro_packages_in_lib(package_lib);
    let primary = annotations.first();
    let module_name = primary
        .map(|meta| meta.module_name.clone())
        .unwrap_or_else(|| {
            let package_name = parse_pubspec_package_name(package_root)
                .or_else(|| {
                    package_root
                        .file_name()
                        .map(|name| name.to_string_lossy().to_string())
                })
                .unwrap_or_else(|| "feature".to_string());
            to_pascal_case(&package_name)
        });

    let mut modules = scan.modules;
    sort_modules(&mut modules);
    let package_name = parse_pubspec_package_name(package_root)
        .or_else(|| {
            package_root
                .file_name()
                .map(|name| name.to_string_lossy().to_string())
        })
        .unwrap_or_default();
    let code = generate_micro_package_code(
        &module_name,
        &modules,
        &package_name,
        package_lib,
        primary.and_then(|meta| meta.prefix.as_deref()),
    );
    write_if_changed(manifest_path, &code)
}

/// Gives every package-owned mount a host marker name that cannot collide with a
/// name the host already uses: `<Feature>Mount` becomes `<Feature><Owner>Mount`,
/// e.g. the package `profile` declaring `ShopMount` next to the host's own
/// `ShopMount` is bound to `ShopProfileMount`.
///
/// A name that is still free is left exactly as the package declared it, so
/// registering a package never renames markers the host already has.
fn qualify_micro_package_markers(micro_packages: &mut [MicroPackageInfo], modules: &[ModuleMetadata]) {
    // The host's own mounts hold their names; a package that wants one of them is
    // the one that moves.
    let mut taken: HashSet<String> = modules
        .iter()
        .map(|module| module.mount_name.clone())
        .collect();

    for micro_package in micro_packages.iter_mut() {
        let owner = micro_package
            .class_name
            .trim_end_matches("KaiselModule")
            .to_string();
        for slot in micro_package.slots.iter_mut() {
            let mut marker = slot.mount_name();
            while taken.contains(&marker) {
                marker = insert_owner(&marker, &owner);
            }
            taken.insert(marker.clone());
            slot.host_marker = marker;
        }
    }
}

/// `ShopMount` + `Profile` → `ShopProfileMount`.
fn insert_owner(marker: &str, owner: &str) -> String {
    match marker.strip_suffix("Mount") {
        Some(feature) => format!("{feature}{owner}Mount"),
        None => format!("{marker}{owner}"),
    }
}

/// Guard rail: the host's own mounts are one namespace, so two modules claiming
/// the same name would silently lose a route. A micro-package cannot cause this
/// — its markers are qualified against whatever the host already declares.
fn validate_mount_names(modules: &[ModuleMetadata]) -> Result<(), String> {
    let mut seen: HashSet<&str> = HashSet::new();
    for module in modules {
        if !seen.insert(&module.mount_name) {
            return Err(format!(
                "Mount name `{}` is declared twice by the host app. Give one module a distinct `mount:` name.",
                module.mount_name
            ));
        }
    }

    Ok(())
}

/// Generates the manifest of a package that is itself a micro-package: no
/// `@KaiselInit` and no `kaisel.yaml`, so no host registry is produced.
fn generate_standalone_micro_package(
    root: &Path,
    lib_dir: &Path,
    modules: &[ModuleMetadata],
    start: Instant,
    files_scanned: usize,
    files_parsed: usize,
) -> GenerationResult {
    let package_name = parse_pubspec_package_name(root)
        .or_else(|| {
            root.file_name()
                .map(|name| name.to_string_lossy().to_string())
        })
        .unwrap_or_else(|| "feature".to_string());

    let annotations = find_micro_packages_in_lib(lib_dir);
    let primary = annotations.first();
    let module_name = primary
        .map(|meta| meta.module_name.clone())
        .unwrap_or_else(|| to_pascal_case(&package_name));
    let manifest_path = match primary.and_then(|meta| meta.output.as_deref()) {
        Some(output) => root.join(output),
        None => lib_dir.join(format!("{package_name}.kaisel.dart")),
    };

    let code = generate_micro_package_code(
        &module_name,
        modules,
        &package_name,
        lib_dir,
        primary.and_then(|meta| meta.prefix.as_deref()),
    );
    if let Err(error) = write_if_changed(&manifest_path, &code) {
        return failure(error, start, files_scanned, files_parsed, modules.len());
    }

    GenerationResult {
        success: true,
        error: None,
        files_scanned,
        files_parsed,
        modules_count: modules.len(),
        elapsed_us: start.elapsed().as_micros(),
        output_path: Some(manifest_path.to_string_lossy().to_string()),
    }
}

pub fn execute_generation(
    project_root: Option<&Path>,
    explicit_lib: Option<&Path>,
    explicit_output: Option<&Path>,
    force: bool,
) -> GenerationResult {
    let start = Instant::now();

    let root = match project_root {
        Some(r) => r.to_path_buf(),
        None => match std::env::current_dir() {
            Ok(cwd) => find_project_root(&cwd).unwrap_or(cwd),
            Err(e) => return failure(format!("Failed to get current directory: {e}"), start, 0, 0, 0),
        },
    };

    let yaml_config = {
        let yaml_path = root.join("kaisel.yaml");
        if yaml_path.exists() {
            parse_kaisel_yaml(&yaml_path)
        } else {
            None
        }
    };

    let lib_dir = explicit_lib
        .map(|p| p.to_path_buf())
        .or_else(|| yaml_config.as_ref().and_then(|c| c.lib_dir.as_ref().map(|d| root.join(d))))
        .unwrap_or_else(|| root.join("lib"));

    let init_meta = find_init_in_lib(&lib_dir);
    let is_host_app = init_meta.is_some() || yaml_config.is_some();

    let output_path = explicit_output
        .map(|p| p.to_path_buf())
        .or_else(|| yaml_config.as_ref().and_then(|c| c.output.as_ref().map(|o| root.join(o))))
        .or_else(|| init_meta.as_ref().and_then(|m| m.output.as_ref().map(|o| root.join(o))))
        .unwrap_or_else(|| root.join("lib").join("app").join("app_modules.g.dart"));

    let route_class = yaml_config
        .as_ref()
        .and_then(|c| c.route_class.as_deref())
        .or_else(|| init_meta.as_ref().and_then(|m| m.route_class.as_deref()))
        .unwrap_or("AppRoute");

    let initial_route_override = yaml_config
        .as_ref()
        .and_then(|c| c.initial_route.as_deref())
        .or_else(|| init_meta.as_ref().and_then(|m| m.initial_route.as_deref()));

    let external_micro_packages = init_meta
        .as_ref()
        .map(|m| m.external_micro_packages.clone())
        .unwrap_or_default();

    let cache = IncrementalCache::new();
    let scan_result = scan_and_extract(&lib_dir, &cache, force);
    let mut modules = scan_result.modules;

    if !is_host_app {
        sort_modules(&mut modules);
        return generate_standalone_micro_package(
            &root,
            &lib_dir,
            &modules,
            start,
            scan_result.files_scanned,
            scan_result.files_parsed,
        );
    }

    sort_modules(&mut modules);

    let output_dir = output_path.parent().unwrap_or(&root).to_path_buf();

    let mut micro_package_infos: Vec<MicroPackageInfo> =
        match resolve_external_micro_packages(
            &root,
            &output_dir,
            &external_micro_packages,
            &cache,
            force,
        ) {
            Ok(externals) => externals,
            Err(error) => {
                return failure(
                    error,
                    start,
                    scan_result.files_scanned,
                    scan_result.files_parsed,
                    modules.len(),
                );
            }
        };

    // Package mounts that would land on a name the host already uses get the owner
    // inserted, so composing a package never needs a hand-picked name.
    qualify_micro_package_markers(&mut micro_package_infos, &modules);

    if let Err(error) = validate_mount_names(&modules) {
        return failure(
            error,
            start,
            scan_result.files_scanned,
            scan_result.files_parsed,
            modules.len(),
        );
    }

    let code = generate_dart_code(
        &modules,
        route_class,
        initial_route_override,
        &micro_package_infos,
        &parse_pubspec_package_name(&root).unwrap_or_default(),
        &lib_dir,
    );
    if let Err(error) = write_if_changed(&output_path, &code) {
        return failure(
            error,
            start,
            scan_result.files_scanned,
            scan_result.files_parsed,
            modules.len(),
        );
    }

    GenerationResult {
        success: true,
        error: None,
        files_scanned: scan_result.files_scanned,
        files_parsed: scan_result.files_parsed,
        modules_count: modules.len(),
        elapsed_us: start.elapsed().as_micros(),
        output_path: Some(output_path.to_string_lossy().to_string()),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::micro_package::MicroPackageSlot;

    fn micro_package(class_name: &str, field_name: &str) -> MicroPackageInfo {
        MicroPackageInfo {
            class_name: class_name.to_string(),
            import_uri: "package:shop/shop.kaisel.dart".to_string(),
            slots: vec![MicroPackageSlot {
                field_name: field_name.to_string(),
                is_routed: true,
                is_initial: false,
                host_marker: String::new(),
            }],
        }
    }

    fn module(mount_name: &str) -> ModuleMetadata {
        ModuleMetadata {
            class_name: "ShopRouterModule".to_string(),
            route_type: "ShopRoute".to_string(),
            mount_name: mount_name.to_string(),
            prefix: Some("/shop".to_string()),
            is_initial: false,
            codec_name: None,
            file_path: PathBuf::from("lib/features/shop/shop_module.dart"),
        }
    }

    #[test]
    fn a_free_name_is_left_alone() {
        let mut packages = vec![micro_package("ProfileKaiselModule", "profileMount")];
        qualify_micro_package_markers(&mut packages, &[module("HomeMount")]);

        assert_eq!(packages[0].slots[0].marker(), "ProfileMount");
    }

    #[test]
    fn a_name_the_host_uses_gets_the_owner_inserted() {
        let mut packages = vec![micro_package("ProfileKaiselModule", "shopMount")];
        qualify_micro_package_markers(&mut packages, &[module("ShopMount")]);

        assert_eq!(packages[0].slots[0].marker(), "ShopProfileMount");
    }

    #[test]
    fn two_packages_claiming_one_name_stay_distinct() {
        let mut packages = vec![
            micro_package("ProfileKaiselModule", "shopMount"),
            micro_package("FeatureShopKaiselModule", "shopMount"),
        ];
        qualify_micro_package_markers(&mut packages, &[module("ShopMount")]);

        assert_eq!(packages[0].slots[0].marker(), "ShopProfileMount");
        assert_eq!(packages[1].slots[0].marker(), "ShopFeatureShopMount");
    }

    #[test]
    fn the_host_cannot_declare_one_mount_twice() {
        let error = validate_mount_names(&[module("ShopMount"), module("ShopMount")])
            .expect_err("a duplicate host mount must fail generation");
        assert!(error.contains("declared twice"), "unexpected error: {error}");
        assert!(validate_mount_names(&[module("ShopMount"), module("HomeMount")]).is_ok());
    }

    #[test]
    fn insert_owner_keeps_the_feature_in_front() {
        assert_eq!(insert_owner("ShopMount", "Profile"), "ShopProfileMount");
        assert_eq!(insert_owner("Shop", "Profile"), "ShopProfile");
    }
}
