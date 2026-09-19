use std::path::PathBuf;
use std::sync::mpsc::channel;
use std::time::{Duration, Instant};

use clap::Parser;
use notify::{Config, Event, RecommendedWatcher, RecursiveMode, Watcher};

use kaisel_generator::config::{execute_generation, find_project_root, parse_kaisel_yaml};

#[derive(Parser, Debug)]
#[command(
    name = "kaisel_generator",
    author = "Kaisel Team",
    version = "0.1.0",
    about = "Blazing-fast Rust-based Dart code generator for Kaisel Module Registry"
)]
struct Cli {
    /// Root path of the Flutter/Dart project (defaults to discovering pubspec.yaml)
    #[arg(short, long)]
    root: Option<PathBuf>,

    /// Path to Dart lib directory (defaults to <root>/lib or kaisel.yaml)
    #[arg(short, long)]
    lib: Option<PathBuf>,

    /// Path for generated output file (defaults to <root>/lib/app/app_modules.g.dart or kaisel.yaml)
    #[arg(short, long)]
    output: Option<PathBuf>,

    /// Watch mode: watch lib directory for changes and regenerate automatically
    #[arg(short, long)]
    watch: bool,

    /// Force generation ignoring caches
    #[arg(short, long)]
    force: bool,
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let cli = Cli::parse();

    let current_dir = std::env::current_dir()?;
    let root = cli
        .root
        .or_else(|| find_project_root(&current_dir))
        .unwrap_or(current_dir);

    // Check for kaisel.yaml in root
    let yaml_config = {
        let yaml_path = root.join("kaisel.yaml");
        if yaml_path.exists() {
            println!("📄 Found config: {}", yaml_path.display());
            parse_kaisel_yaml(&yaml_path)
        } else {
            None
        }
    };

    let lib_dir = cli
        .lib
        .or_else(|| yaml_config.as_ref().and_then(|c| c.lib_dir.as_ref().map(|d| root.join(d))))
        .unwrap_or_else(|| root.join("lib"));

    let output_path = cli
        .output
        .or_else(|| yaml_config.as_ref().and_then(|c| c.output.as_ref().map(|o| root.join(o))));

    println!("🦀 Kaisel Module Registry Generator");
    println!("   Root: {}", root.display());
    println!("   Lib:  {}", lib_dir.display());

    let result = execute_generation(
        Some(&root),
        Some(&lib_dir),
        output_path.as_deref(),
        cli.force,
    );

    if !result.success {
        eprintln!("❌ Error: {}", result.error.unwrap_or_default());
        std::process::exit(1);
    }

    let elapsed_display = if result.elapsed_us >= 1000 {
        format!("{} ms", result.elapsed_us / 1000)
    } else {
        format!("{} µs", result.elapsed_us)
    };

    println!(
        "⚡ Generated {} mounts from {} modules ({} files scanned, {} parsed) in {}",
        result.modules_count,
        result.modules_count,
        result.files_scanned,
        result.files_parsed,
        elapsed_display
    );
    if let Some(out) = result.output_path {
        println!("   Output: {}", out);
    }

    if cli.watch {
        println!("\n👀 Watching for changes in {}...", lib_dir.display());

        let (tx, rx) = channel();
        let mut watcher = RecommendedWatcher::new(tx, Config::default())?;
        watcher.watch(&lib_dir, RecursiveMode::Recursive)?;

        let mut last_run = Instant::now();
        loop {
            match rx.recv() {
                Ok(Ok(Event { paths, .. })) => {
                    let has_dart_change = paths.iter().any(|p| {
                        p.extension().is_some_and(|ext| ext == "dart")
                            && !p.to_string_lossy().ends_with(".g.dart")
                    });

                    if has_dart_change && last_run.elapsed() > Duration::from_millis(150) {
                        last_run = Instant::now();
                        let res = execute_generation(
                            Some(&root),
                            Some(&lib_dir),
                            output_path.as_deref(),
                            false,
                        );
                        if res.success {
                            println!("⚡ Re-generated in {} ms", res.elapsed_us / 1000);
                        } else {
                            eprintln!("❌ Error: {}", res.error.unwrap_or_default());
                        }
                    }
                }
                Ok(Err(e)) => eprintln!("Watch error: {e:?}"),
                Err(e) => {
                    eprintln!("Channel error: {e:?}");
                    break;
                }
            }
        }
    }

    Ok(())
}
