use std::path::{Path, PathBuf};
use tree_sitter::{Node, Parser};

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ModuleMetadata {
    pub class_name: String,
    pub route_type: String,
    pub mount_name: String,
    pub prefix: Option<String>,
    pub is_initial: bool,
    pub codec_name: Option<String>,
    pub file_path: PathBuf,
}

#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct InitMetadata {
    pub output: Option<String>,
    pub route_class: Option<String>,
    pub initial_route: Option<String>,
    pub external_micro_packages: Vec<ExternalMicroPackageRef>,
}

/// A `ExternalMicroPackage(<ModuleClass>)` entry declared on `@KaiselInit`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ExternalMicroPackageRef {
    /// The micro-package module class, e.g. `FeatureShopKaiselModule`.
    pub module: String,
    /// Explicit manifest import URI, when the convention cannot be used.
    pub import: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct MicroPackageMetadata {
    pub module_name: String,
    pub output: Option<String>,
    pub prefix: Option<String>,
    pub file_path: PathBuf,
}

pub fn extract_modules_from_source(file_path: &Path, source: &str) -> Vec<ModuleMetadata> {
    let mut parser = Parser::new();
    let language = tree_sitter_dart::LANGUAGE;
    parser
        .set_language(&language.into())
        .expect("Error loading Dart grammar");

    let tree = match parser.parse(source, None) {
        Some(t) => t,
        None => return Vec::new(),
    };

    let mut modules = Vec::new();
    let root = tree.root_node();
    extract_modules_from_node(root, source, file_path, &mut modules);
    modules
}

pub fn extract_init_metadata(source: &str) -> Option<InitMetadata> {
    // Parse a comment-free copy: `externalMicroPackages` is read by scanning the
    // argument text, so a commented-out `ExternalMicroPackage(...)` — or a `)`
    // inside a comment — must not read as a registration. [strip_dart_comments]
    // keeps every byte offset, so node ranges still slice the same text.
    let source = strip_dart_comments(source);

    let mut parser = Parser::new();
    let language = tree_sitter_dart::LANGUAGE;
    parser
        .set_language(&language.into())
        .expect("Error loading Dart grammar");

    let tree = parser.parse(&source, None)?;
    let root = tree.root_node();
    find_init_in_node(root, &source)
}

pub fn extract_micro_package_metadata(file_path: &Path, source: &str) -> Option<MicroPackageMetadata> {
    let mut parser = Parser::new();
    let language = tree_sitter_dart::LANGUAGE;
    parser
        .set_language(&language.into())
        .expect("Error loading Dart grammar");

    let tree = parser.parse(source, None)?;
    let root = tree.root_node();
    find_micro_package_in_node(root, source, file_path)
}

fn find_init_in_node(node: Node, source: &str) -> Option<InitMetadata> {
    if node.kind() == "annotation" || node.kind() == "metadata" {
        let annot_text = node_text(node, source);
        if annot_text.contains("KaiselInit") {
            let mut output = None;
            let mut route_class = None;
            let mut initial_route = None;
            let mut external_micro_packages = Vec::new();

            find_init_annotation_args(
                node,
                source,
                &mut output,
                &mut route_class,
                &mut initial_route,
                &mut external_micro_packages,
            );
            return Some(InitMetadata {
                output,
                route_class,
                initial_route,
                external_micro_packages,
            });
        }
    }

    let mut cursor = node.walk();
    for child in node.children(&mut cursor) {
        if let Some(meta) = find_init_in_node(child, source) {
            return Some(meta);
        }
    }
    None
}

fn find_init_annotation_args(
    annot_node: Node,
    source: &str,
    output: &mut Option<String>,
    route_class: &mut Option<String>,
    initial_route: &mut Option<String>,
    external_micro_packages: &mut Vec<ExternalMicroPackageRef>,
) {
    let mut cursor = annot_node.walk();
    for child in annot_node.children(&mut cursor) {
        if child.kind() == "annotation_arguments" || child.kind() == "arguments" {
            let mut arg_cursor = child.walk();
            for arg_child in child.children(&mut arg_cursor) {
                if arg_child.kind() == "named_argument" {
                    let mut name = String::new();
                    let mut val = String::new();

                    let mut named_cursor = arg_child.walk();
                    for part in arg_child.children(&mut named_cursor) {
                        if part.kind() == "label" {
                            name = node_text(part, source)
                                .trim_end_matches(':')
                                .trim()
                                .to_string();
                        } else if part.kind() != ":" {
                            val = node_text(part, source).trim().to_string();
                        }
                    }

                    match name.as_str() {
                        "output" => *output = Some(val.trim_matches('\'').trim_matches('"').to_string()),
                        "routeClass" | "route_class" => *route_class = Some(val.trim_matches('\'').trim_matches('"').to_string()),
                        "initialRoute" | "initial_route" => *initial_route = Some(val.trim_matches('\'').trim_matches('"').to_string()),
                        "externalMicroPackages" | "external_micro_packages" => {
                            *external_micro_packages = parse_external_micro_packages(&val);
                        }
                        _ => {}
                    }
                }
            }
        }
    }
}

/// Parses `[ExternalMicroPackage(ShopModule), ExternalMicroPackage(PostsModule, import: '...')]`.
fn parse_external_micro_packages(list_text: &str) -> Vec<ExternalMicroPackageRef> {
    let mut result = Vec::new();
    let mut rest = list_text;

    while let Some(found) = rest.find("ExternalMicroPackage") {
        rest = &rest[found + "ExternalMicroPackage".len()..];
        let Some(open) = rest.find('(') else {
            continue;
        };
        let Some(close) = rest[open + 1..].find(')').map(|offset| offset + open + 1) else {
            continue;
        };
        let arguments = &rest[open + 1..close];
        rest = &rest[close + 1..];

        let mut parts = arguments.split(',');
        let module = parts
            .next()
            .unwrap_or_default()
            .split('<')
            .next()
            .unwrap_or_default()
            .trim();
        if module.is_empty() {
            continue;
        }

        let import = parts.find_map(|part| {
            let value = part.trim().strip_prefix("import:")?.trim();
            let value = value.trim_matches('\'').trim_matches('"');
            (!value.is_empty()).then(|| value.to_string())
        });

        result.push(ExternalMicroPackageRef {
            module: module.to_string(),
            import,
        });
    }

    result
}

/// Replaces Dart comments with spaces, keeping every byte offset and newline in
/// place so parsed node ranges stay valid.
///
/// String literals are skipped wholesale, so a `//` inside one is not a comment.
pub fn strip_dart_comments(source: &str) -> String {
    let bytes = source.as_bytes();
    let mut out = bytes.to_vec();
    let mut idx = 0;

    while idx < bytes.len() {
        match bytes[idx] {
            b'/' if idx + 1 < bytes.len() && bytes[idx + 1] == b'/' => {
                while idx < bytes.len() && bytes[idx] != b'\n' {
                    out[idx] = b' ';
                    idx += 1;
                }
            }
            b'/' if idx + 1 < bytes.len() && bytes[idx + 1] == b'*' => {
                out[idx] = b' ';
                out[idx + 1] = b' ';
                idx += 2;
                while idx < bytes.len() {
                    if bytes[idx] == b'*' && idx + 1 < bytes.len() && bytes[idx + 1] == b'/' {
                        out[idx] = b' ';
                        out[idx + 1] = b' ';
                        idx += 2;
                        break;
                    }
                    if bytes[idx] != b'\n' {
                        out[idx] = b' ';
                    }
                    idx += 1;
                }
            }
            quote @ (b'\'' | b'"') => idx = skip_string(bytes, idx, quote),
            _ => idx += 1,
        }
    }

    String::from_utf8(out).unwrap_or_else(|_| source.to_string())
}

/// Index just past the string literal starting at `start`, or the line end when
/// it is unterminated.
fn skip_string(bytes: &[u8], start: usize, quote: u8) -> usize {
    let raw = start > 0 && matches!(bytes[start - 1], b'r' | b'R');
    let triple = start + 2 < bytes.len() && bytes[start + 1] == quote && bytes[start + 2] == quote;
    let mut idx = if triple { start + 3 } else { start + 1 };

    while idx < bytes.len() {
        let byte = bytes[idx];
        if triple {
            let closes = byte == quote
                && bytes.get(idx + 1) == Some(&quote)
                && bytes.get(idx + 2) == Some(&quote);
            if closes {
                return idx + 3;
            }
        } else if byte == quote {
            return idx + 1;
        } else if byte == b'\n' {
            return idx;
        }

        if byte == b'\\' && !raw {
            idx += 2;
        } else {
            idx += 1;
        }
    }

    idx
}

fn find_micro_package_in_node(
    node: Node,
    source: &str,
    file_path: &Path,
) -> Option<MicroPackageMetadata> {
    if node.kind() == "annotation" || node.kind() == "metadata" {
        let annot_text = node_text(node, source);
        if annot_text.contains("KaiselMicroPackage") {
            let mut module_name = String::new();
            let mut output = None;
            let mut prefix = None;

            find_micro_package_args(node, source, &mut module_name, &mut output, &mut prefix);
            if !module_name.is_empty() {
                return Some(MicroPackageMetadata {
                    module_name,
                    output,
                    prefix,
                    file_path: file_path.to_path_buf(),
                });
            }
        }
    }

    let mut cursor = node.walk();
    for child in node.children(&mut cursor) {
        if let Some(meta) = find_micro_package_in_node(child, source, file_path) {
            return Some(meta);
        }
    }
    None
}

fn find_micro_package_args(
    annot_node: Node,
    source: &str,
    module_name: &mut String,
    output: &mut Option<String>,
    prefix: &mut Option<String>,
) {
    let mut cursor = annot_node.walk();
    for child in annot_node.children(&mut cursor) {
        if child.kind() == "annotation_arguments" || child.kind() == "arguments" {
            let mut arg_cursor = child.walk();
            for arg_child in child.children(&mut arg_cursor) {
                if arg_child.kind() == "named_argument" {
                    let mut name = String::new();
                    let mut val = String::new();

                    let mut named_cursor = arg_child.walk();
                    for part in arg_child.children(&mut named_cursor) {
                        if part.kind() == "label" {
                            name = node_text(part, source)
                                .trim_end_matches(':')
                                .trim()
                                .to_string();
                        } else if part.kind() != ":" {
                            val = node_text(part, source).trim().to_string();
                        }
                    }

                    let clean_val = val.trim_matches('\'').trim_matches('"').to_string();
                    match name.as_str() {
                        "moduleName" | "module_name" => *module_name = clean_val,
                        "output" => *output = Some(clean_val),
                        "prefix" => *prefix = Some(clean_val),
                        _ => {}
                    }
                }
            }
        }
    }
}

fn extract_modules_from_node(
    node: Node,
    source: &str,
    file_path: &Path,
    modules: &mut Vec<ModuleMetadata>,
) {
    if node.kind() == "class_declaration" {
        if let Some(meta) = inspect_class_node(node, source, file_path) {
            modules.push(meta);
        }
    }

    let mut cursor = node.walk();
    for child in node.children(&mut cursor) {
        extract_modules_from_node(child, source, file_path, modules);
    }
}

fn node_text<'a>(node: Node<'a>, source: &'a str) -> &'a str {
    &source[node.start_byte()..node.end_byte()]
}

fn inspect_class_node(
    class_node: Node,
    source: &str,
    file_path: &Path,
) -> Option<ModuleMetadata> {
    let mut has_kaisel_annotation = false;
    let mut prefix: Option<String> = None;
    let mut mount_name: Option<String> = None;
    let mut is_initial = false;
    let mut explicit_codec: Option<String> = None;

    // Look for metadata/annotations attached to this class or preceding it
    let mut cursor = class_node.walk();
    for child in class_node.children(&mut cursor) {
        if child.kind() == "annotation" || child.kind() == "metadata" {
            let annot_text = node_text(child, source);
            if annot_text.contains("KaiselModule") {
                has_kaisel_annotation = true;
                find_annotation_args(
                    child,
                    source,
                    &mut prefix,
                    &mut mount_name,
                    &mut is_initial,
                    &mut explicit_codec,
                );
            }
        }
    }

    if !has_kaisel_annotation {
        return None;
    }

    let class_name = class_node
        .child_by_field_name("name")
        .map(|n| node_text(n, source).to_string())
        .or_else(|| {
            let mut c = class_node.walk();
            for ch in class_node.children(&mut c) {
                if ch.kind() == "identifier" {
                    return Some(node_text(ch, source).to_string());
                }
            }
            None
        })?;

    // Extract superclass and generic route type
    let mut route_type = String::new();
    let mut superclass_cursor = class_node.walk();
    for child in class_node.children(&mut superclass_cursor) {
        if child.kind() == "superclass" {
            let super_text = node_text(child, source);
            if let Some(start) = super_text.find('<') {
                if let Some(end) = super_text.rfind('>') {
                    route_type = super_text[start + 1..end].trim().to_string();
                }
            }
        }
    }

    if route_type.is_empty() {
        let base = class_name
            .trim_end_matches("RouterModule")
            .trim_end_matches("Module");
        route_type = format!("{base}Route");
    }

    // Default mount name to <Feature>Mount
    let default_mount = {
        let base = class_name
            .trim_end_matches("RouterModule")
            .trim_end_matches("Module");
        format!("{base}Mount")
    };

    let mount = mount_name.unwrap_or(default_mount);

    // Look for getter `codec` or fallback by convention to <RouteType>Codec
    let codec_name = explicit_codec
        .or_else(|| find_codec_getter(class_node, source))
        .or_else(|| Some(format!("{route_type}Codec")));

    Some(ModuleMetadata {
        class_name,
        route_type,
        mount_name: mount,
        prefix,
        is_initial,
        codec_name,
        file_path: file_path.to_path_buf(),
    })
}

fn find_annotation_args(
    annot_node: Node,
    source: &str,
    prefix: &mut Option<String>,
    mount_name: &mut Option<String>,
    is_initial: &mut bool,
    explicit_codec: &mut Option<String>,
) {
    let mut cursor = annot_node.walk();
    for child in annot_node.children(&mut cursor) {
        if child.kind() == "annotation_arguments" || child.kind() == "arguments" {
            let mut arg_cursor = child.walk();
            for arg_child in child.children(&mut arg_cursor) {
                if arg_child.kind() == "named_argument" {
                    let mut name = String::new();
                    let mut val = String::new();

                    let mut named_cursor = arg_child.walk();
                    for part in arg_child.children(&mut named_cursor) {
                        if part.kind() == "label" {
                            name = node_text(part, source)
                                .trim_end_matches(':')
                                .trim()
                                .to_string();
                        } else if part.kind() != ":" {
                            val = node_text(part, source).trim().to_string();
                        }
                    }

                    match name.as_str() {
                        "prefix" => {
                            *prefix = Some(val.trim_matches('\'').trim_matches('"').to_string());
                        }
                        "mount" => {
                            *mount_name =
                                Some(val.trim_matches('\'').trim_matches('"').to_string());
                        }
                        "isInitial" => {
                            *is_initial = val == "true";
                        }
                        "codec" => {
                            *explicit_codec = Some(val);
                        }
                        _ => {}
                    }
                }
            }
        }
    }
}

fn find_codec_getter(class_node: Node, source: &str) -> Option<String> {
    let class_text = node_text(class_node, source);
    for line in class_text.lines() {
        let trimmed = line.trim();
        if trimmed.contains("get codec") || (trimmed.contains("codec") && trimmed.contains("=>")) {
            if let Some((_, after)) = trimmed.split_once("=>") {
                let expr = after.trim().trim_end_matches(';').trim();
                let clean = expr
                    .trim_start_matches("const")
                    .trim()
                    .trim_end_matches("()")
                    .trim();
                if !clean.is_empty() {
                    return Some(clean.to_string());
                }
            }
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_parse_kaisel_module_with_prefix_and_codec() {
        let dart_code = r#"
        @KaiselModule(prefix: '/shop', codec: ShopRouteCodec)
        class ShopRouterModule extends RouteModule<ShopRoute> {
          const ShopRouterModule();
        }
        "#;

        let modules = extract_modules_from_source(&PathBuf::from("lib/features/shop/shop_module.dart"), dart_code);
        assert_eq!(modules.len(), 1);
        let m = &modules[0];
        assert_eq!(m.class_name, "ShopRouterModule");
        assert_eq!(m.route_type, "ShopRoute");
        assert_eq!(m.mount_name, "ShopMount");
        assert_eq!(m.prefix.as_deref(), Some("/shop"));
        assert!(!m.is_initial);
        assert_eq!(m.codec_name.as_deref(), Some("ShopRouteCodec"));
    }

    #[test]
    fn test_parse_kaisel_module_initial() {
        let dart_code = r#"
        @KaiselModule(isInitial: true)
        class HomeRouterModule extends RouteModule<HomeRoute> {
          const HomeRouterModule();
        }
        "#;

        let modules = extract_modules_from_source(&PathBuf::from("lib/features/home/home_module.dart"), dart_code);
        assert_eq!(modules.len(), 1);
        let m = &modules[0];
        assert_eq!(m.class_name, "HomeRouterModule");
        assert_eq!(m.route_type, "HomeRoute");
        assert_eq!(m.mount_name, "HomeMount");
        assert_eq!(m.prefix, None);
        assert!(m.is_initial);
    }

    #[test]
    fn test_parse_kaisel_module_with_getter_codec() {
        let dart_code = r#"
        @KaiselModule(prefix: '/settings')
        class SettingsRouterModule extends RouteModule<SettingsRoute> {
          const SettingsRouterModule();

          @override
          ModuleStackCodec<SettingsRoute> get codec => const SettingsRouteCodec();
        }
        "#;

        let modules = extract_modules_from_source(&PathBuf::from("lib/features/settings/settings_module.dart"), dart_code);
        assert_eq!(modules.len(), 1);
        let m = &modules[0];
        assert_eq!(m.codec_name.as_deref(), Some("SettingsRouteCodec"));
    }

    #[test]
    fn test_parse_kaisel_init_function() {
        let dart_code = r#"
        @KaiselInit(
          output: 'lib/app/custom_modules.g.dart',
          routeClass: 'CustomRoute',
          initialRoute: 'CustomHomeMount',
          useMicroPackage: true,
          externalMicroPackages: [
            ExternalMicroPackage(ShopKaiselModule),
            ExternalMicroPackage(
              PostsKaiselModule,
              import: 'package:feature_posts/src/posts.kaisel.dart',
            ),
          ],
        )
        void configureRouting() {}
        "#;

        let init = extract_init_metadata(dart_code).expect("should parse @KaiselInit");
        assert_eq!(init.output.as_deref(), Some("lib/app/custom_modules.g.dart"));
        assert_eq!(init.route_class.as_deref(), Some("CustomRoute"));
        assert_eq!(init.initial_route.as_deref(), Some("CustomHomeMount"));
        assert_eq!(
            init.external_micro_packages,
            vec![
                ExternalMicroPackageRef {
                    module: "ShopKaiselModule".to_string(),
                    import: None,
                },
                ExternalMicroPackageRef {
                    module: "PostsKaiselModule".to_string(),
                    import: Some("package:feature_posts/src/posts.kaisel.dart".to_string()),
                },
            ]
        );
    }

    #[test]
    fn test_parse_kaisel_init_ignores_commented_external_packages() {
        // Commented-out registrations are inert: the package is not composed, so
        // the host never tries to resolve a manifest for it.
        let dart_code = r#"
        @KaiselInit(
          externalMicroPackages: [
            // ExternalMicroPackage(ProfileKaiselModule),
            /* ExternalMicroPackage(OldKaiselModule), */
          ],
        )
        void configureRouting() {}
        "#;

        let init = extract_init_metadata(dart_code).expect("init should parse");
        assert!(init.external_micro_packages.is_empty());
    }

    #[test]
    fn test_parse_kaisel_init_keeps_live_entries_around_comments() {
        // The `)` and `import:` inside the comments must not truncate or invent
        // the surrounding declarations.
        let dart_code = r#"
        @KaiselInit(
          externalMicroPackages: [
            // ExternalMicroPackage(ProfileKaiselModule),
            ExternalMicroPackage(ShopKaiselModule),
            ExternalMicroPackage(
              // import: 'package:feature_posts/old.kaisel.dart'),
              PostsKaiselModule,
              import: 'package:feature_posts/feature_posts.kaisel.dart',
            ),
          ],
        )
        void configureRouting() {}
        "#;

        let init = extract_init_metadata(dart_code).expect("init should parse");
        assert_eq!(
            init.external_micro_packages,
            vec![
                ExternalMicroPackageRef {
                    module: "ShopKaiselModule".to_string(),
                    import: None,
                },
                ExternalMicroPackageRef {
                    module: "PostsKaiselModule".to_string(),
                    import: Some(
                        "package:feature_posts/feature_posts.kaisel.dart".to_string()
                    ),
                },
            ]
        );
    }

    #[test]
    fn test_strip_dart_comments_keeps_string_literals() {
        let source = "final a = 'x // y'; // trailing\nfinal b = \"/* z */\";\n";
        let stripped = strip_dart_comments(source);

        assert!(stripped.contains("'x // y'"));
        assert!(stripped.contains("\"/* z */\""));
        assert!(!stripped.contains("trailing"));
        // Offsets and line count survive, so parsed node ranges stay valid.
        assert_eq!(stripped.len(), source.len());
    }

    #[test]
    fn test_parse_kaisel_micro_package() {
        let dart_code = r#"
        @KaiselMicroPackage(moduleName: 'Shop', prefix: '/shop')
        void configureShopRoutes() {}
        "#;

        let mp = extract_micro_package_metadata(
            &PathBuf::from("lib/features/shop/shop_micro_package.dart"),
            dart_code,
        ).expect("should parse @KaiselMicroPackage");

        assert_eq!(mp.module_name, "Shop");
        assert_eq!(mp.prefix.as_deref(), Some("/shop"));
    }
}
