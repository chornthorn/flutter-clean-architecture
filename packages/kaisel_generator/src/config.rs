use std::fs;
use std::path::{Path, PathBuf};
use std::time::Instant;
use serde::{Deserialize, Serialize};

use crate::generator::generate_dart_code;
use crate::parser::extract_init_metadata;
use crate::scanner::{scan_and_extract, IncrementalCache};

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct KaiselConfigFile {
    pub output: Option<PathBuf>,
    pub lib_dir: Option<PathBuf>,
    pub route_class: Option<String>,
}

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

pub fn parse_kaisel_yaml(path: &Path) -> Option<KaiselConfigFile> {
    let content = fs::read_to_string(path).ok()?;
    let mut config = KaiselConfigFile::default();
    for line in content.lines() {
        let line = line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        if let Some((key, val)) = line.split_once(':') {
            let key = key.trim();
            let val = val.trim().trim_matches('\'').trim_matches('"');
            match key {
                "output" => config.output = Some(PathBuf::from(val)),
                "lib_dir" | "lib" => config.lib_dir = Some(PathBuf::from(val)),
                "route_class" => config.route_class = Some(val.to_string()),
                _ => {}
            }
        }
    }
    Some(config)
}

pub fn find_project_root(start: &Path) -> Option<PathBuf> {
    let mut current = start.to_path_buf();
    // First, check if current or any parent has kaisel.yaml
    let mut temp = current.clone();
    loop {
        if temp.join("kaisel.yaml").exists() {
            return Some(temp);
        }
        if !temp.pop() {
            break;
        }
    }

    // Otherwise find the pubspec.yaml that is NOT packages/kaisel_generator itself
    loop {
        if current.join("pubspec.yaml").exists() {
            if let Ok(content) = fs::read_to_string(current.join("pubspec.yaml")) {
                if !content.contains("name: kaisel_generator") {
                    return Some(current);
                }
            } else {
                return Some(current);
            }
        }
        if !current.pop() {
            break;
        }
    }
    None
}

pub fn find_init_in_lib(lib_dir: &Path) -> Option<PathBuf> {
    for entry in walkdir::WalkDir::new(lib_dir).into_iter().filter_map(|e| e.ok()) {
        let path = entry.path();
        if path.extension().is_some_and(|ext| ext == "dart") {
            if let Ok(content) = fs::read_to_string(path) {
                if content.contains("KaiselInit") {
                    if let Some(init_meta) = extract_init_metadata(&content) {
                        if let Some(out) = init_meta.output {
                            return Some(PathBuf::from(out));
                        }
                    }
                }
            }
        }
    }
    None
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
            Err(e) => {
                return GenerationResult {
                    success: false,
                    error: Some(format!("Failed to get current directory: {e}")),
                    files_scanned: 0,
                    files_parsed: 0,
                    modules_count: 0,
                    elapsed_us: 0,
                    output_path: None,
                };
            }
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

    let output_path = explicit_output
        .map(|p| p.to_path_buf())
        .or_else(|| yaml_config.as_ref().and_then(|c| c.output.as_ref().map(|o| root.join(o))))
        .or_else(|| find_init_in_lib(&lib_dir).map(|p| root.join(p)))
        .unwrap_or_else(|| root.join("lib").join("app").join("app_modules.g.dart"));

    let cache = IncrementalCache::new();
    let scan_result = scan_and_extract(&lib_dir, &cache, force);
    let mut modules = scan_result.modules;

    modules.sort_by(|a, b| {
        b.is_initial
            .cmp(&a.is_initial)
            .then_with(|| a.mount_name.cmp(&b.mount_name))
    });

    let code = generate_dart_code(&modules, &output_path);

    if let Some(parent) = output_path.parent() {
        if let Err(e) = fs::create_dir_all(parent) {
            return GenerationResult {
                success: false,
                error: Some(format!("Failed to create output directory: {e}")),
                files_scanned: scan_result.files_scanned,
                files_parsed: scan_result.files_parsed,
                modules_count: modules.len(),
                elapsed_us: start.elapsed().as_micros(),
                output_path: Some(output_path.to_string_lossy().to_string()),
            };
        }
    }

    let should_write = match fs::read_to_string(&output_path) {
        Ok(existing) => existing != code,
        Err(_) => true,
    };

    if should_write {
        if let Err(e) = fs::write(&output_path, &code) {
            return GenerationResult {
                success: false,
                error: Some(format!("Failed to write output file: {e}")),
                files_scanned: scan_result.files_scanned,
                files_parsed: scan_result.files_parsed,
                modules_count: modules.len(),
                elapsed_us: start.elapsed().as_micros(),
                output_path: Some(output_path.to_string_lossy().to_string()),
            };
        }
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
