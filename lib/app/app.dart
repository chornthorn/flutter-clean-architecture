import 'package:flutter/material.dart';
import 'package:kaisel/kaisel.dart';

import '../core/design_system/app_theme.g.dart';
import 'app_codec.dart';
import 'app_page_builder.dart';
import 'app_route.dart';

// The app's router, created once at top level.
final appRouterConfig = KaiselRouterConfig<AppRoute>(
  initial: const HomeMount(),
  builder: buildAppPage,
  codec: appCodec,
);

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
