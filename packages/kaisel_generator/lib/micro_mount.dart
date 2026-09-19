/// Runtime helpers for kaisel micro-packages.
///
/// Generated code imports **this** library, which is a separate entrypoint for a
/// reason: `package:kaisel_generator/kaisel_generator.dart` is the CLI's
/// entrypoint, so it must import neither kaisel (the CLI runs under plain
/// `dart run`, without the Flutter tool) nor the analyzer an app build has no
/// use for.
///
/// A micro-package declares what it contributes ([KaiselMicroMount]) and the
/// host application binds each declaration to one of its own marker routes. The
/// host passes the marker *instance*, so a mount is never looked up by name —
/// renaming or removing a mount is a compile error, not a silent fallback.
library;

import 'package:kaisel/kaisel.dart';

/// One mount a micro-package contributes to a host application.
///
/// Declared by the micro-package in its generated `<package>.kaisel.dart`, and
/// bound by the host through [KaiselMicroMountX.moduleMount].
final class KaiselMicroMount<M extends KaiselRoute> {
  const KaiselMicroMount({
    required this.module,
    required this.codec,
    this.prefix,
    this.isInitial = false,
  });

  /// The module that owns this mount: its routes, initial stack and pages.
  final RouteModule<M> module;

  /// The module's codec, used to compose the mount's URLs under [prefix].
  final ModuleStackCodec<M> codec;

  /// The URL prefix this mount owns, or `null` when the module is not
  /// URL-routed and the host only renders it.
  final String? prefix;

  /// Whether the host should land on this mount by default.
  final bool isInitial;
}

/// Composition helpers, used by the host's generated registry.
extension KaiselMicroMountX<M extends KaiselRoute> on KaiselMicroMount<M> {
  /// The page a host renders for its marker route that mounts this declaration.
  ///
  /// The module's own typed sub-router is created inside [KaiselModuleMount];
  /// the host never dispatches the module's routes.
  KaiselModuleMount<M> get page => KaiselModuleMount<M>(module: module);

  /// This declaration as a URL-composition mount on the host's route type,
  /// bound to [mountRoute] — the host's marker for this micro-package mount.
  ModuleMount<H> moduleMount<H extends KaiselRoute>(H mountRoute) {
    final prefix = this.prefix;
    if (prefix == null) {
      throw StateError(
        'Micro-package mount `${module.runtimeType}` is not URL-routed, so it '
        'cannot be declared in `appModuleMounts`. Regenerate the host registry.',
      );
    }
    return ModuleMount<H>(mountRoute: mountRoute, prefix: prefix, codec: codec);
  }

  /// Canonical URL of this mount's root — its prefix plus the module's initial
  /// stack — or `null` when the module is not URL-routed.
  Uri? get url {
    final prefix = this.prefix;
    if (prefix == null) {
      return null;
    }
    final segments = <String>[
      ...prefix.split('/').where((segment) => segment.isNotEmpty),
      ...codec.encode(module.initialStack),
    ];
    return Uri(path: segments.isEmpty ? '/' : '/${segments.join('/')}');
  }
}
