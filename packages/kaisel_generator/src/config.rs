use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::time::Instant;

use serde::{Deserialize, Serialize};

use crate::generator::{
    generate_dart_code, generate_micro_package_code, relative_import, MicroPackageInfo,
};
use crate::micro_package::{
    extract_micro_package_manifest, infer_import_uri, resolve_import_file,
    resolve_package_lib_dir, to_camel_case, to_pascal_case, MicroPackageSlot,
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
    pub use_micro_package: Option<bool>,
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
                "use_micro_package" => config.use_micro_package = Some(val == "true"),
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

/// A `@KaiselMicroPackage` boundary found in the host's own `lib/`.
struct DiscoveredMicroPackage {
    meta: MicroPackageMetadata,
    /// Where the generated manifest is written. Not `meta.output`, which is
    /// resolved against the project root.
    manifest_path: PathBuf,
}

fn default_manifest_path(base_dir: &Path, meta: &MicroPackageMetadata) -> PathBuf {
    match &meta.output {
        Some(output) => base_dir.join(output),
        None => {
            let stem = meta
                .file_path
                .file_stem()
                .unwrap_or_default()
                .to_string_lossy();
            meta.file_path.with_file_name(format!("{stem}.kaisel.dart"))
        }
    }
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

/// Finds micro-package boundaries inside the host's own `lib/`.
///
/// Only the host project is scanned. A feature that lives in a separate package
/// generates its own manifest and the host composes it through
/// `ExternalMicroPackage(...)`; it is never written from here.
fn discover_local_micro_packages(root: &Path, lib_dir: &Path) -> Vec<DiscoveredMicroPackage> {
    find_micro_packages_in_lib(lib_dir)
        .into_iter()
        .map(|meta| DiscoveredMicroPackage {
            manifest_path: default_manifest_path(root, &meta),
            meta,
        })
        .collect()
}

/// Writes a micro-package manifest and returns the metadata the host needs to
/// compose it.
fn materialize_micro_package(
    discovered: &DiscoveredMicroPackage,
    modules: &[ModuleMetadata],
    output_dir: &Path,
    route_class: &str,
) -> Result<MicroPackageInfo, String> {
    let mp_modules: Vec<ModuleMetadata> = modules
        .iter()
        .filter(|module| module.file_path.starts_with(&discovered.meta.folder_path))
        .cloned()
        .collect();

    let code = generate_micro_package_code(
        &discovered.meta.module_name,
        &mp_modules,
        &discovered.manifest_path,
        route_class,
        discovered.meta.prefix.as_deref(),
    );
    write_if_changed(&discovered.manifest_path, &code)?;

    let import_uri = relative_import(&discovered.manifest_path, output_dir);

    let slots = mp_modules
        .iter()
        .map(|module| MicroPackageSlot {
            field_name: to_camel_case(&module.mount_name),
            is_routed: module.prefix.is_some(),
            is_initial: module.is_initial,
        })
        .collect();

    Ok(MicroPackageInfo {
        class_name: format!("{}KaiselModule", discovered.meta.module_name),
        import_uri,
        file_path: Some(discovered.manifest_path.clone()),
        slots,
    })
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

        if !manifest_path.exists() {
            if let Some(package_lib) = package_lib_dir_within_project(root, &import_uri)? {
                ensure_package_manifest(&package_lib, &manifest_path, cache, force)?;
            }
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
            file_path: Some(manifest_path),
            slots: manifest.slots,
        });
    }

    Ok(resolved)
}

/// Whether `candidate` was already composed from an explicit
/// `ExternalMicroPackage(...)` registration: the same module class, the same
/// manifest file, or the same providing package.
fn is_already_composed(candidate: &MicroPackageInfo, composed: &[MicroPackageInfo]) -> bool {
    composed.iter().any(|existing| {
        existing.class_name == candidate.class_name
            || match (&existing.file_path, &candidate.file_path) {
                (Some(existing), Some(candidate)) => existing == candidate,
                _ => false,
            }
            || match (
                package_name_of(&existing.import_uri),
                package_name_of(&candidate.import_uri),
            ) {
                (Some(existing), Some(candidate)) => existing == candidate,
                _ => false,
            }
    })
}

/// The package name of a `package:<name>/<path>` import URI.
fn package_name_of(import_uri: &str) -> Option<&str> {
    import_uri
        .strip_prefix("package:")?
        .split('/')
        .next()
        .filter(|name| !name.is_empty())
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
    let code = generate_micro_package_code(
        &module_name,
        &modules,
        manifest_path,
        "AppRoute",
        primary.and_then(|meta| meta.prefix.as_deref()),
    );
    write_if_changed(manifest_path, &code)
}

/// Guard rail: every mount name maps to exactly one owner, otherwise the
/// generated sealed hierarchy silently loses routes.
fn validate_mount_names(
    modules: &[ModuleMetadata],
    micro_packages: &[MicroPackageInfo],
) -> Result<(), String> {
    let owner_of = |module: &ModuleMetadata| -> String {
        micro_packages
            .iter()
            .position(|mp| {
                mp.file_path
                    .as_ref()
                    .and_then(|path| path.parent())
                    .is_some_and(|dir| module.file_path.starts_with(dir))
            })
            .map(|idx| micro_packages[idx].class_name.clone())
            .unwrap_or_else(|| "the host app".to_string())
    };

    let mut owners: HashMap<String, String> = HashMap::new();
    for module in modules {
        let owner = owner_of(module);
        let previous = owners.insert(module.mount_name.clone(), owner.clone());
        let conflict = previous.filter(|previous| *previous != owner);
        if let Some(previous) = conflict {
            return Err(format!(
                "Mount name `{}` is declared by both {previous} and {owner}. Give one module a distinct `mount:` name.",
                module.mount_name
            ));
        }
    }

    for micro_package in micro_packages {
        for slot in &micro_package.slots {
            let name = slot.mount_name();
            match owners.get(&name) {
                Some(owner) if owner != &micro_package.class_name => {
                    return Err(format!(
                        "Mount name `{name}` from `{}` collides with a route declared by {owner}. Give one module a distinct `mount:` name.",
                        micro_package.class_name
                    ));
                }
                Some(_) => {}
                None => {
                    owners.insert(name, micro_package.class_name.clone());
                }
            }
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
    route_class: &str,
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
        &manifest_path,
        route_class,
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

    let compose_discovered_micro_packages = yaml_config
        .as_ref()
        .and_then(|c| c.use_micro_package)
        .or_else(|| init_meta.as_ref().and_then(|m| m.use_micro_package))
        .unwrap_or(true);

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
            route_class,
            start,
            scan_result.files_scanned,
            scan_result.files_parsed,
        );
    }

    let discovered = discover_local_micro_packages(&root, &lib_dir);
    sort_modules(&mut modules);

    let output_dir = output_path.parent().unwrap_or(&root).to_path_buf();

    // Manifests of micro-packages inside the host's own `lib/` are written first,
    // so an explicit registration pointing at one resolves against current
    // output. Foreign packages are never written here: they generate their own
    // manifest, and the host only composes it.
    let mut discovered_infos: Vec<MicroPackageInfo> = Vec::new();
    for micro_package in &discovered {
        match materialize_micro_package(micro_package, &modules, &output_dir, route_class) {
            Ok(info) => discovered_infos.push(info),
            Err(error) => {
                return failure(
                    error,
                    start,
                    scan_result.files_scanned,
                    scan_result.files_parsed,
                    modules.len(),
                );
            }
        }
    }

    // Explicitly registered micro-packages come first: they are the host's
    // declared composition, so discovery must not shadow them with an equivalent
    // package (and discard a custom `import:`).
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

    for info in discovered_infos {
        if !compose_discovered_micro_packages || is_already_composed(&info, &micro_package_infos) {
            continue;
        }
        micro_package_infos.push(info);
    }

    if let Err(error) = validate_mount_names(&modules, &micro_package_infos) {
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
        &output_path,
        route_class,
        initial_route_override,
        &micro_package_infos,
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

    fn micro_package(class_name: &str, import_uri: &str, file_path: &str) -> MicroPackageInfo {
        MicroPackageInfo {
            class_name: class_name.to_string(),
            import_uri: import_uri.to_string(),
            file_path: Some(PathBuf::from(file_path)),
            slots: vec![MicroPackageSlot {
                field_name: "profileMount".to_string(),
                is_routed: true,
                is_initial: false,
            }],
        }
    }

    #[test]
    fn external_registration_claims_matching_class_name() {
        let registered = micro_package(
            "ProfileKaiselModule",
            "package:profile/profile.kaisel.dart",
            "features/profile/lib/profile.kaisel.dart",
        );
        let discovered = micro_package(
            "ProfileKaiselModule",
            "../features/profile/lib/profile.kaisel.dart",
            "features/profile/lib/profile.kaisel.dart",
        );

        assert!(is_already_composed(&discovered, &[registered]));
    }

    #[test]
    fn external_registration_claims_the_same_package_under_other_names() {
        let registered = micro_package(
            "ProfileKaiselModule",
            "package:profile/profile.kaisel.dart",
            "deps/profile/lib/profile.kaisel.dart",
        );
        let discovered = micro_package(
            "ProfileFeatureKaiselModule",
            "package:profile/other.kaisel.dart",
            "features/profile/lib/other.kaisel.dart",
        );

        assert!(is_already_composed(&discovered, &[registered]));
    }

    #[test]
    fn unrelated_package_is_not_claimed() {
        let registered = micro_package(
            "ProfileKaiselModule",
            "package:profile/profile.kaisel.dart",
            "features/profile/lib/profile.kaisel.dart",
        );
        let discovered = micro_package(
            "ShopKaiselModule",
            "package:shop/shop.kaisel.dart",
            "features/shop/lib/shop.kaisel.dart",
        );

        assert!(!is_already_composed(&discovered, &[registered]));
    }

    #[test]
    fn folder_scoped_packages_are_only_claimed_by_name() {
        let local = micro_package(
            "ShopKaiselModule",
            "../features/shop/shop_micro_package.kaisel.dart",
            "lib/features/shop/shop_micro_package.kaisel.dart",
        );

        assert!(!is_already_composed(&local, &[]));
        assert!(is_already_composed(&local, std::slice::from_ref(&local)));
    }

    #[test]
    fn package_name_of_reads_package_uris() {
        assert_eq!(
            package_name_of("package:profile/profile.kaisel.dart"),
            Some("profile")
        );
        assert_eq!(package_name_of("../features/profile/profile.kaisel.dart"), None);
        assert_eq!(package_name_of("package:/profile.dart"), None);
    }
}
