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

/// Marks the application entry point to configure Kaisel code generation.
class KaiselInit {
  /// Path to the generated output file (e.g. `'lib/app/app_modules.g.dart'`).
  final String? output;

  /// Name of the base sealed route class (e.g. `'AppRoute'`).
  final String? routeClass;

  const KaiselInit({
    this.output,
    this.routeClass,
  });
}
