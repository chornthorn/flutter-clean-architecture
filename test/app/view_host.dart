import 'package:flutter/material.dart';
import 'package:flutter_x/core/design_system/app_theme.g.dart';
import 'package:provider/provider.dart';

// One notifier for the whole test run. `themeData` is a getter over immutable
// token maps, so sharing it costs nothing.
final _theme = AppThemeNotifier(initialMode: AppThemeMode.light);

// Pumps a page the way the app runs it, for every feature's view tests. It stands
// in for `lib/app/app.dart` (the shell that carries the theme) plus the feature
// module's provider, minus the router.
//
// `.value` hands over a view model the test owns — `ChangeNotifierProvider.value`
// has no dispose callback, so the provider will not dispose it.
Widget hostPage<T extends ChangeNotifier>(T viewModel, Widget page) =>
    ChangeNotifierProvider<T>.value(value: viewModel, child: hostShell(page));

// The same host for a view model that is not a `ChangeNotifier` — one that
// publishes signals instead. `Provider.value` does not listen, so the page
// rebuilds off whatever the view model publishes rather than off notifications,
// and the test still owns the dispose.
Widget hostSignalPage<T>(T viewModel, Widget page) =>
    Provider<T>.value(value: viewModel, child: hostShell(page));

// The same shell for a widget that needs the app's theme and a navigator but no
// view model — a dialog, say. A page that reads `context.theme` throws without
// this, so anything pumped bare belongs here.
Widget hostShell(Widget home) =>
    MaterialApp(theme: _theme.themeData, home: home);
