import 'package:flutter/material.dart';
import 'package:kaisel/kaisel.dart';

import '../core/design_system/app_theme.g.dart';
import 'app_codec.dart';
import 'app_page_builder.dart';
import 'app_route.dart';

// The app's router. A top-level `final`, so it lives as long as the app.
final appRouterConfig = KaiselRouterConfig<AppRoute>(
  initial: const HomeMount(),
  builder: buildAppPage,
  codec: appCodec,
);

// Owns the theme notifier for the app's lifetime. `AppThemeProvider.builder`
// rebuilds `MaterialApp` on a mode change, which is what swaps the token set.
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
