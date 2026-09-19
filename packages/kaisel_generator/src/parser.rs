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
    let mut parser = Parser::new();
    let language = tree_sitter_dart::LANGUAGE;
    parser
        .set_language(&language.into())
        .expect("Error loading Dart grammar");

    let tree = parser.parse(source, None)?;
    let root = tree.root_node();
    find_init_in_node(root, source)
}

fn find_init_in_node(node: Node, source: &str) -> Option<InitMetadata> {
    if node.kind() == "annotation" || node.kind() == "metadata" {
        let annot_text = node_text(node, source);
        if annot_text.contains("KaiselInit") {
            let mut output = None;
            let mut route_class = None;
            let mut initial_route = None;
            find_init_annotation_args(node, source, &mut output, &mut route_class, &mut initial_route);
            return Some(InitMetadata { output, route_class, initial_route });
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
                        "output" => *output = Some(clean_val),
                        "routeClass" | "route_class" => *route_class = Some(clean_val),
                        "initialRoute" | "initial_route" => *initial_route = Some(clean_val),
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
        )
        void configureRouting() {}
        "#;

        let init = extract_init_metadata(dart_code).expect("should parse @KaiselInit");
        assert_eq!(init.output.as_deref(), Some("lib/app/custom_modules.g.dart"));
        assert_eq!(init.route_class.as_deref(), Some("CustomRoute"));
        assert_eq!(init.initial_route.as_deref(), Some("CustomHomeMount"));
    }
}
