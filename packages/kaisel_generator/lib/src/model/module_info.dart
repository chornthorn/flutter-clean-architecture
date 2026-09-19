/// What a scan of a package's `lib/` finds.
///
/// These are plain values read from source, so they can be asserted on without a
/// build: the scan needs an AST, never a resolved program.
library;

/// One `@KaiselModule` class, with the names its registry entry needs.
class ModuleInfo {
  const ModuleInfo({
    required this.className,
    required this.routeType,
    required this.mountName,
    required this.codecName,
    required this.filePath,
    this.prefix,
    this.isInitial = false,
  });

  /// The module class, e.g. `ShopRouterModule`.
  final String className;

  /// The module's route family, e.g. `ShopRoute`.
  final String routeType;

  /// The host marker route generated for this module, e.g. `ShopMount`.
  final String mountName;

  /// The module's codec, e.g. `ShopRouteCodec`. Never null: a module without an
  /// explicit `codec:` or `codec` getter falls back to `<routeType>Codec`.
  final String codecName;

  /// Absolute path of the file that declares the module.
  final String filePath;

  /// URL prefix the module owns, or `null` when it is not URL-routed.
  final String? prefix;

  /// Whether the host should land on this mount by default.
  final bool isInitial;

  /// Whether this module owns a URL prefix, and so belongs in `appModuleMounts`.
  bool get isRouted => prefix != null;
}

/// What one scan of a package's `lib/` found.
class ModuleScanResult {
  const ModuleScanResult({
    required this.modules,
    required this.filesScanned,
    required this.filesParsed,
  });

  /// Every `@KaiselModule` class, in file order.
  final List<ModuleInfo> modules;

  /// `.dart` files the walk considered.
  final int filesScanned;

  /// Files that named an annotation and were therefore parsed.
  final int filesParsed;
}
