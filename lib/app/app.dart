import 'package:flutter/material.dart';
import 'package:kaisel_generator/kaisel_generator.dart';

import 'package:profile/profile.kaisel.dart';

import '../core/design_system/app_theme.g.dart';
import 'app_modules.g.dart';

// Public API export: exposes AppRoute, mounts, defaultAppCodec, etc.
export 'app_modules.g.dart';

// Decoupled routing configuration similar to @InjectableInit / @CqrsInit.
@KaiselInit(
  externalMicroPackages: [
    // `features/profile` is a package in this project: this run generates its
    // manifest and composes it.
    ExternalMicroPackage(ProfileKaiselModule),
  ],
)
void configureRouting() {}

// The app's router, configured from the generated module registry.
final appRouterConfig = defaultAppRouterConfig;

/// Root application widget.
class KaiselApp extends StatefulWidget {
  const KaiselApp({super.key});

  @override
  State<KaiselApp> createState() => _KaiselAppState();
}

class _KaiselAppState extends State<KaiselApp> {
  final _theme = AppThemeNotifier(initialMode: AppThemeMode.light);

  @override
  void dispose() {
    _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppThemeProvider.builder(
      notifier: _theme,
      builder: (context, theme) => MaterialApp.router(
        title: 'kaisel features',
        theme: theme.themeData,
        routerConfig: appRouterConfig,
      ),
    );
  }
}
