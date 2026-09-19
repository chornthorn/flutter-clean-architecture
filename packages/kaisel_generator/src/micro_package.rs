//! Resolution of `@KaiselMicroPackage` modules consumed by a host application.
//!
//! A micro-package is an independent Dart package that generates its own
//! `<package>.kaisel.dart` manifest. The manifest exposes a small, stable
//! contract (`mountNames`, `mountPrefixes`, `initialMount`) so a host
//! application can compose it without scanning the micro-package sources.

use std::fs;
use std::path::{Component, Path, PathBuf};

use serde::Deserialize;

/// Machine-readable contract of a generated micro-package manifest.
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct MicroPackageManifest {
    /// Generated registry class, e.g. `FeatureShopKaiselModule`.
    pub class_name: String,
    /// Mount declarations, in declaration order.
    pub slots: Vec<MicroPackageSlot>,
}

/// One mount a micro-package declares through `KaiselMicroMount`.
///
/// The host binds each declaration to one of its own marker routes, so the
/// manifest carries no route names a host could dispatch on by string.
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct MicroPackageSlot {
    /// Field name of the declaration, e.g. `shopMount`.
    pub field_name: String,
    /// Whether the declaration owns a URL prefix.
    pub is_routed: bool,
    /// Whether the host should land on this mount by default.
    pub is_initial: bool,
}

impl MicroPackageSlot {
    /// Host marker class this slot is bound to, e.g. `ShopMount`.
    pub fn mount_name(&self) -> String {
        to_pascal_case(&self.field_name)
    }
}

/// Derives the conventional manifest import URI for a micro-package module class.
///
/// `FeatureShopKaiselModule` resolves to
/// `package:feature_shop/feature_shop.kaisel.dart`.
pub fn infer_import_uri(module_class: &str) -> Option<String> {
    let base = module_class
        .strip_suffix("KaiselModule")
        .or_else(|| module_class.strip_suffix("Module"))?;
    if base.is_empty() {
        return None;
    }
    let package = to_snake_case(base);
    if package.is_empty() {
        return None;
    }
    Some(format!("package:{package}/{package}.kaisel.dart"))
}

/// Extracts the manifest contract from generated `<package>.kaisel.dart` source.
///
/// Returns `None` when the source was not produced by a compatible generator
/// (no `KaiselMicroMount` registry class).
pub fn extract_micro_package_manifest(source: &str) -> Option<MicroPackageManifest> {
    let class_name = extract_registry_class_name(source)?;

    // Manifests written before mounts became typed declarations carry a
    // `mountNames` index instead. Composing one would silently contribute no
    // mounts at all, so reject it and let the caller ask for regeneration.
    if source.contains("mountNames") && !source.contains(SLOT_MARKER) {
        return None;
    }

    let mut slots = Vec::new();
    let mut cursor = 0;
    while let Some(offset) = source[cursor..].find(SLOT_MARKER) {
        let start = cursor + offset + SLOT_MARKER.len();
        let Some((field_name, declaration)) = split_slot_declaration(&source[start..]) else {
            break;
        };
        slots.push(MicroPackageSlot {
            field_name,
            is_routed: declaration.contains("prefix:"),
            is_initial: declaration.contains("isInitial: true"),
        });
        cursor = start;
    }

    Some(MicroPackageManifest { class_name, slots })
}

/// Marker that starts a mount declaration, e.g.
/// `static const KaiselMicroMount<ShopRoute> shopMount = ...`.
const SLOT_MARKER: &str = "static const KaiselMicroMount<";

/// Marker that starts the registry class a host composes.
const CLASS_MARKER: &str = "abstract final class ";

/// Closing delimiter the emitter writes at the end of a slot declaration.
const SLOT_END: &str = "\n  );";

fn extract_registry_class_name(source: &str) -> Option<String> {
    let start = source.find(CLASS_MARKER)? + CLASS_MARKER.len();
    let rest = &source[start..];
    let end = rest
        .find(|c: char| !(c.is_alphanumeric() || c == '_'))
        .unwrap_or(rest.len());
    let name = &rest[..end];
    name.ends_with("KaiselModule").then(|| name.to_string())
}

/// Splits `ShopRoute> shopMount = KaiselMicroMount<ShopRoute>(...)` into the
/// field name and the declaration body.
fn split_slot_declaration(rest: &str) -> Option<(String, String)> {
    let type_end = rest.find('>')?;
    let after_type = &rest[type_end + 1..];
    let equals = after_type.find('=')?;

    let field_name = after_type[..equals].trim();
    let is_identifier = !field_name.is_empty()
        && field_name
            .chars()
            .all(|c| c.is_alphanumeric() || c == '_');
    if !is_identifier {
        return None;
    }

    Some((
        field_name.to_string(),
        declaration_body(&after_type[equals + 1..]),
    ))
}

/// The declaration body of a slot: up to its closing delimiter, or up to the
/// next declaration when the file was written by a different emitter.
fn declaration_body(body: &str) -> String {
    let end = body.find(SLOT_END).or_else(|| body.find(SLOT_MARKER));
    body[..end.unwrap_or(body.len())].to_string()
}

/// Resolves the manifest file of an import URI to a path on disk.
///
/// `package:` imports are resolved through the host's
/// `.dart_tool/package_config.json`; relative imports are resolved against the
/// directory of the generated output file.
pub fn resolve_import_file(
    root: &Path,
    output_dir: &Path,
    import_uri: &str,
) -> Result<PathBuf, String> {
    let resolved = if let Some(rest) = import_uri.strip_prefix("package:") {
        let (package, path) = rest.split_once('/').ok_or_else(|| {
            format!("Invalid micro-package import `{import_uri}`: expected `package:<name>/<path>`")
        })?;
        let lib_dir = lookup_package_lib_dir(root, package)?;
        lib_dir.join(path)
    } else if import_uri.starts_with("file:") {
        file_uri_to_path(import_uri, output_dir)
    } else if Path::new(import_uri).is_absolute() {
        PathBuf::from(import_uri)
    } else {
        output_dir.join(import_uri)
    };

    // The host compares resolved manifests against scanned source paths to decide
    // ownership, so `.`/`..` components (a relative `rootUri` produces them) must
    // not survive here.
    Ok(normalize_path(&resolved))
}

/// Removes `.` and `..` components without touching the filesystem, so paths to
/// files that do not exist yet still resolve predictably.
fn normalize_path(path: &Path) -> PathBuf {
    let mut normalized = PathBuf::new();
    for component in path.components() {
        match component {
            Component::CurDir => {}
            Component::ParentDir => {
                let pop = matches!(
                    normalized.components().next_back(),
                    Some(Component::Normal(_))
                );
                if pop {
                    normalized.pop();
                } else if !normalized.has_root() {
                    normalized.push("..");
                }
            }
            other => normalized.push(other.as_os_str()),
        }
    }
    normalized
}

/// Resolves the `lib/` directory of a dependency package listed in
/// `<root>/.dart_tool/package_config.json`.
pub fn resolve_package_lib_dir(root: &Path, package: &str) -> Result<PathBuf, String> {
    lookup_package_lib_dir(root, package)
}

fn lookup_package_lib_dir(root: &Path, package: &str) -> Result<PathBuf, String> {
    let config_path = root.join(".dart_tool").join("package_config.json");
    let raw = fs::read_to_string(&config_path).map_err(|e| {
        format!(
            "Could not read `{}` to resolve `package:{package}`: {e}. Run `dart pub get` in the host app.",
            config_path.display()
        )
    })?;

    let config: PackageConfigFile = serde_json::from_str(&raw)
        .map_err(|e| format!("Invalid `{}`: {e}", config_path.display()))?;

    let base_dir = config_path.parent().unwrap_or(root);
    let entry = config
        .packages
        .iter()
        .find(|entry| entry.name == package)
        .ok_or_else(|| {
            format!(
                "Package `{package}` is not declared in `{}`. Add it to the host's pubspec.yaml and run `dart pub get`.",
                config_path.display()
            )
        })?;

    let package_root = if entry.root_uri.starts_with("file:") {
        file_uri_to_path(&entry.root_uri, base_dir)
    } else {
        base_dir.join(&entry.root_uri)
    };
    let package_uri = entry.package_uri.as_deref().unwrap_or("lib/");

    // `rootUri` is relative for path dependencies, so normalizing here keeps
    // scanned module paths comparable to manifest paths (and to the host root).
    Ok(normalize_path(&package_root.join(package_uri)))
}

#[derive(Debug, Deserialize)]
struct PackageConfigFile {
    packages: Vec<PackageConfigEntry>,
}

#[derive(Debug, Deserialize)]
struct PackageConfigEntry {
    name: String,
    #[serde(rename = "rootUri")]
    root_uri: String,
    #[serde(rename = "packageUri")]
    package_uri: Option<String>,
}

fn file_uri_to_path(uri: &str, base_dir: &Path) -> PathBuf {
    let raw = uri.strip_prefix("file://").unwrap_or(uri);
    let decoded = percent_decode(raw);
    let path = PathBuf::from(decoded);
    if path.is_absolute() {
        path
    } else {
        base_dir.join(path)
    }
}

fn percent_decode(input: &str) -> String {
    let bytes = input.as_bytes();
    let mut out: Vec<u8> = Vec::with_capacity(bytes.len());
    let mut idx = 0;
    while idx < bytes.len() {
        match decode_escape(bytes, idx) {
            Some((byte, next)) => {
                out.push(byte);
                idx = next;
            }
            None => {
                out.push(bytes[idx]);
                idx += 1;
            }
        }
    }
    String::from_utf8_lossy(&out).into_owned()
}

/// Decodes a `%XX` escape starting at `idx`, returning the byte and the next
/// index to read.
fn decode_escape(bytes: &[u8], idx: usize) -> Option<(u8, usize)> {
    if bytes[idx] != b'%' || idx + 2 >= bytes.len() {
        return None;
    }
    let high = hex_value(bytes[idx + 1])?;
    let low = hex_value(bytes[idx + 2])?;
    Some((high * 16 + low, idx + 3))
}

fn hex_value(byte: u8) -> Option<u8> {
    match byte {
        b'0'..=b'9' => Some(byte - b'0'),
        b'a'..=b'f' => Some(byte - b'a' + 10),
        b'A'..=b'F' => Some(byte - b'A' + 10),
        _ => None,
    }
}

/// Converts `FeatureShop` to `feature_shop`.
pub fn to_snake_case(value: &str) -> String {
    let mut result = String::with_capacity(value.len() + 4);
    for (idx, ch) in value.chars().enumerate() {
        if ch.is_uppercase() {
            if idx > 0 && !result.ends_with('_') {
                result.push('_');
            }
            for lower in ch.to_lowercase() {
                result.push(lower);
            }
        } else {
            result.push(ch);
        }
    }
    result
}

/// Converts `feature_shop` to `FeatureShop`.
pub fn to_pascal_case(value: &str) -> String {
    let mut result = String::with_capacity(value.len());
    let mut capitalize_next = true;
    for ch in value.chars() {
        if ch == '_' || ch == '-' || ch == ' ' {
            capitalize_next = true;
            continue;
        }
        if capitalize_next {
            for upper in ch.to_uppercase() {
                result.push(upper);
            }
            capitalize_next = false;
        } else {
            result.push(ch);
        }
    }
    result
}

/// Converts `ShopMount` to `shopMount`, the field a manifest declares for it.
pub fn to_camel_case(value: &str) -> String {
    let mut chars = value.chars();
    let Some(first) = chars.next() else {
        return String::new();
    };
    let mut result: String = first.to_lowercase().collect();
    result.push_str(chars.as_str());
    result
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicU64, Ordering};

    const SAMPLE_MANIFEST: &str = r#"
// GENERATED CODE - DO NOT MODIFY BY HAND
import 'package:kaisel_generator/micro_mount.dart';

import './src/shop_module.dart' as i1;

/// Micro-package module registry for `FeatureShop`.
abstract final class FeatureShopKaiselModule {
  /// The mount this package contributes for `homeMount`.
  static const KaiselMicroMount<i1.HomeRoute> homeMount = KaiselMicroMount<i1.HomeRoute>(
    module: i1.HomeRouterModule(),
    codec: i1.HomeRouteCodec(),
    isInitial: true,
  );

  /// The mount this package contributes for `shopMount`.
  static const KaiselMicroMount<i1.ShopRoute> shopMount = KaiselMicroMount<i1.ShopRoute>(
    prefix: '/shop',
    module: i1.ShopRouterModule(),
    codec: i1.ShopRouteCodec(),
  );
}
"#;

    #[test]
    fn test_infer_import_uri() {
        assert_eq!(
            infer_import_uri("FeatureShopKaiselModule").as_deref(),
            Some("package:feature_shop/feature_shop.kaisel.dart")
        );
        assert_eq!(
            infer_import_uri("ShopModule").as_deref(),
            Some("package:shop/shop.kaisel.dart")
        );
        assert_eq!(infer_import_uri("Shop"), None);
    }

    #[test]
    fn test_case_conversion() {
        assert_eq!(to_snake_case("FeatureShop"), "feature_shop");
        assert_eq!(to_snake_case("Feature_shop"), "feature_shop");
        assert_eq!(to_pascal_case("feature_shop"), "FeatureShop");
        assert_eq!(to_pascal_case("feature-shop"), "FeatureShop");
    }

    #[test]
    fn test_mount_field_names_round_trip_to_marker_names() {
        for mount in ["HomeMount", "ShopMount", "AdminPanelMount", "Mount2"] {
            let slot = MicroPackageSlot {
                field_name: to_camel_case(mount),
                ..Default::default()
            };
            assert_eq!(slot.mount_name(), mount);
        }
    }

    #[test]
    fn test_extract_manifest_slots() {
        let manifest =
            extract_micro_package_manifest(SAMPLE_MANIFEST).expect("manifest should parse");
        assert_eq!(manifest.class_name, "FeatureShopKaiselModule");
        assert_eq!(
            manifest.slots,
            vec![
                MicroPackageSlot {
                    field_name: "homeMount".to_string(),
                    is_routed: false,
                    is_initial: true,
                },
                MicroPackageSlot {
                    field_name: "shopMount".to_string(),
                    is_routed: true,
                    is_initial: false,
                },
            ]
        );
        assert_eq!(manifest.slots[1].mount_name(), "ShopMount");
    }

    #[test]
    fn test_extract_manifest_without_mounts() {
        let source = SAMPLE_MANIFEST
            .split("  /// The mount this package contributes for `homeMount`.")
            .next()
            .unwrap()
            .to_string()
            + "}\n";
        let manifest = extract_micro_package_manifest(&source).expect("manifest should parse");
        assert!(manifest.slots.is_empty());
    }

    #[test]
    fn test_extract_manifest_rejects_foreign_source() {
        assert!(extract_micro_package_manifest("class Legacy {}").is_none());
        assert!(extract_micro_package_manifest("abstract final class AppRoute {}").is_none());
    }

    #[test]
    fn test_extract_manifest_rejects_name_based_contract() {
        let legacy = r#"
abstract final class ShopKaiselModule {
  static const List<String> mountNames = <String>['ShopMount'];
}
"#;
        assert!(extract_micro_package_manifest(legacy).is_none());
    }

    #[test]
    fn test_resolve_relative_import_file() {
        let output_dir = Path::new("/tmp/host/lib/app");
        let resolved =
            resolve_import_file(Path::new("/tmp/host"), output_dir, "../shop/shop.kaisel.dart")
                .expect("relative import should resolve");
        assert_eq!(resolved, PathBuf::from("/tmp/host/lib/shop/shop.kaisel.dart"));
    }

    #[test]
    fn test_resolve_package_import_through_package_config() {
        let fixture = TempDir::new("resolve_package");
        let package_root = fixture.path.join("feature_shop");
        fs::create_dir_all(package_root.join("lib")).unwrap();
        fs::create_dir_all(fixture.path.join(".dart_tool")).unwrap();

        let config = format!(
            r#"{{"configVersion":2,"packages":[{{"name":"feature_shop","rootUri":"file://{}","packageUri":"lib/","languageVersion":"3.0"}}]}}"#,
            package_root.display()
        );
        fs::write(fixture.path.join(".dart_tool/package_config.json"), config).unwrap();

        let resolved = resolve_import_file(
            &fixture.path,
            &fixture.path.join("lib/app"),
            "package:feature_shop/feature_shop.kaisel.dart",
        )
        .expect("package import should resolve");

        assert_eq!(resolved, package_root.join("lib/feature_shop.kaisel.dart"));
    }

    #[test]
    fn test_resolve_package_import_without_pub_get_is_actionable() {
        let fixture = TempDir::new("missing_package_config");
        let error = resolve_import_file(
            &fixture.path,
            &fixture.path.join("lib/app"),
            "package:feature_shop/feature_shop.kaisel.dart",
        )
        .expect_err("missing package_config should fail");
        assert!(error.contains("dart pub get"), "unexpected error: {error}");
    }

    #[test]
    fn test_resolve_package_import_with_relative_root_uri_is_normalized() {
        let fixture = TempDir::new("relative_root_uri");
        let package_root = fixture.path.join("features/profile");
        fs::create_dir_all(package_root.join("lib")).unwrap();
        fs::create_dir_all(fixture.path.join(".dart_tool")).unwrap();

        // `dart pub get` writes relative `rootUri`s for path dependencies.
        let config = r#"{"configVersion":2,"packages":[{"name":"profile","rootUri":"../features/profile","packageUri":"lib/","languageVersion":"3.0"}]}"#;
        fs::write(fixture.path.join(".dart_tool/package_config.json"), config).unwrap();

        let resolved = resolve_import_file(
            &fixture.path,
            &fixture.path.join("lib/app"),
            "package:profile/profile.kaisel.dart",
        )
        .expect("relative rootUri should resolve");

        assert_eq!(resolved, package_root.join("lib/profile.kaisel.dart"));
    }

    #[test]
    fn test_normalize_path() {
        assert_eq!(normalize_path(Path::new("a/../b/./c")), PathBuf::from("b/c"));
        assert_eq!(normalize_path(Path::new("/a/../../b")), PathBuf::from("/b"));
        assert_eq!(normalize_path(Path::new("../a")), PathBuf::from("../a"));
    }

    struct TempDir {
        path: PathBuf,
    }

    impl TempDir {
        fn new(label: &str) -> Self {
            static COUNTER: AtomicU64 = AtomicU64::new(0);
            let unique = COUNTER.fetch_add(1, Ordering::Relaxed);
            let path = std::env::temp_dir().join(format!(
                "kaisel_generator_{label}_{}_{unique}",
                std::process::id()
            ));
            fs::create_dir_all(&path).unwrap();
            Self { path }
        }
    }

    impl Drop for TempDir {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.path);
        }
    }
}
