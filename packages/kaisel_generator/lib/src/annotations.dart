/// Marks a `RouteModule` class for automatic registration in the host's
/// `AppRoute` hierarchy, `buildAppModulePage`, and `ConfigCodecWithModules`.
class KaiselModule {
  /// The URL prefix under which this module is mounted (e.g. `'/shop'`).
  ///
  /// If `null`, the module is not given a URL route in `ModuleMount`.
  final String? prefix;

  /// Custom name for the generated host route mount marker (e.g. `'ShopMount'`).
  ///
  /// Defaults to `<Feature>Mount` if omitted.
  final String? mount;

  /// Whether this module represents the default initial landing route.
  ///
  /// Defaults to `false`.
  final bool isInitial;

  /// Explicit `KaiselConfigCodec` or `ModuleStackCodec` type.
  ///
  /// If omitted, the generator inspects the module's `codec` getter or falls
  /// back to `<Feature>RouteCodec`.
  final Type? codec;

  const KaiselModule({
    this.prefix,
    this.mount,
    this.isInitial = false,
    this.codec,
  });
}

/// Marks a folder or sub-package boundary as a Kaisel micro-package module.
///
/// Feature modules inside this folder (and subdirectories) are scoped
/// to this micro-package rather than directly to the root application.
///
/// A package that declares this annotation and no `@KaiselInit` generates
/// `<package>.kaisel.dart` with a `<moduleName>KaiselModule` registry,
/// which host applications compose through
/// `@KaiselInit(externalMicroPackages: [...])`.
class KaiselMicroPackage {
  /// The unique name of this micro-package module (e.g. `'Shop'`).
  final String moduleName;

  /// Optional custom output path for this micro-package's generated manifest.
  /// Defaults to `<filename>.kaisel.dart` when composed by a host, or
  /// `<package>.kaisel.dart` when generated standalone.
  final String? output;

  /// Optional base URL prefix prepended to all modules mounted within.
  final String? prefix;

  const KaiselMicroPackage({
    required this.moduleName,
    this.output,
    this.prefix,
  });
}

/// Reference to an external micro-package that the host composes through
/// `@KaiselInit(externalMicroPackages: [...])`.
class ExternalMicroPackage {
  /// The micro-package module class (e.g. `FeatureShopKaiselModule`).
  final Type module;

  /// Import URI of the micro-package's generated manifest.
  ///
  /// When omitted, the generator infers
  /// `package:<snake_case(module)>/<snake_case(module)>.kaisel.dart` from
  /// [module]; for example `FeatureShopKaiselModule` resolves to
  /// `package:feature_shop/feature_shop.kaisel.dart`.
  final String? import;

  const ExternalMicroPackage(this.module, {this.import});
}

/// Marks the application entry point to configure Kaisel code generation.
///
/// Can annotate a top-level configuration function (similar to `@InjectableInit()`
/// or `@CqrsInit()`, e.g. `configureRouting()`), a class, or top-level variable,
/// decoupling route setup from any specific Widget implementation.
class KaiselInit {
  /// Path to the generated output file (e.g. `'lib/app/app_modules.g.dart'`).
  final String? output;

  /// Name of the base sealed route class (e.g. `'AppRoute'`).
  final String? routeClass;

  /// Name of the initial route / default module mount (e.g. `'HomeMount'`).
  final String? initialRoute;

  /// Whether to automatically discover and compose folder-scoped
  /// micro-packages (`@KaiselMicroPackage`) found in `lib/` and
  /// `features/<package>/lib`.
  ///
  /// Defaults to `null`, which enables discovery; set to `false` to mount the
  /// modules of those folders directly from the host instead.
  final bool? useMicroPackage;

  /// External micro-packages to compose into the host registry.
  ///
  /// Each entry's generated manifest is imported into the host file and its
  /// mounts, page builders, URL prefixes and initial route are composed with
  /// the host's own modules.
  final List<ExternalMicroPackage>? externalMicroPackages;

  const KaiselInit({
    this.output,
    this.routeClass,
    this.initialRoute,
    this.useMicroPackage,
    this.externalMicroPackages,
  });
}
