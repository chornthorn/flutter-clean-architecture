use std::fs;
use std::path::{Path, PathBuf};
use std::sync::Mutex;
use std::collections::HashMap;

use ignore::WalkBuilder;
use rayon::prelude::*;

use crate::parser::{extract_modules_from_source, ModuleMetadata};

pub struct ScanResult {
    pub modules: Vec<ModuleMetadata>,
    pub files_scanned: usize,
    pub files_parsed: usize,
}

#[derive(Default)]
pub struct IncrementalCache {
    hashes: Mutex<HashMap<PathBuf, blake3::Hash>>,
}

impl IncrementalCache {
    pub fn new() -> Self {
        Self::default()
    }
}

pub fn scan_and_extract(
    search_dir: &Path,
    cache: &IncrementalCache,
    force: bool,
) -> ScanResult {
    // Collect all .dart candidate files respecting .gitignore
    let dart_files: Vec<PathBuf> = WalkBuilder::new(search_dir)
        .hidden(true)
        .git_ignore(true)
        .build()
        .filter_map(|entry| entry.ok())
        .filter(|entry| {
            let path = entry.path();
            path.is_file()
                && path.extension().is_some_and(|ext| ext == "dart")
                && !path.to_string_lossy().ends_with(".g.dart")
        })
        .map(|entry| entry.into_path())
        .collect();

    let files_scanned = dart_files.len();
    let files_parsed = Mutex::new(0);

    // Parallel extraction with Rayon
    let modules: Vec<ModuleMetadata> = dart_files
        .par_iter()
        .flat_map(|path| {
            let content = match fs::read_to_string(path) {
                Ok(c) => c,
                Err(_) => return Vec::new(),
            };

            // Quick check if file could contain KaiselModule before full AST parse
            if !content.contains("KaiselModule") {
                return Vec::new();
            }

            let hash = blake3::hash(content.as_bytes());

            if !force {
                let mut guard = cache.hashes.lock().unwrap();
                if let Some(prev) = guard.get(path) {
                    if *prev == hash {
                        // Unchanged; still parse if we need module metadata
                    }
                }
                guard.insert(path.clone(), hash);
            }

            {
                let mut count = files_parsed.lock().unwrap();
                *count += 1;
            }

            extract_modules_from_source(path, &content)
        })
        .collect();

    let parsed_count = *files_parsed.lock().unwrap();

    ScanResult {
        modules,
        files_scanned,
        files_parsed: parsed_count,
    }
}
