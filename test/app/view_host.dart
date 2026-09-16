import 'package:flutter/material.dart';
import 'package:flutter_x/core/design_system/app_theme.g.dart';
import 'package:provider/provider.dart';

// One notifier for the whole test run. `themeData` is a getter over immutable
// token maps, so sharing it costs nothing.
final _theme = AppThemeNotifier(initialMode: AppThemeMode.light);

// Pumps a page the way the app runs it, for every feature's view tests: the app's
// theme, and the route's provider above the page.
//
// `.value` hands over a view model the test owns — `Provider.value` has no dispose
// callback, so the provider will not dispose it, and the test keeps ownership.
// What changes inside is a signal, which the page picks up through its own
// `SignalBuilder` rather than through a notification.
Widget hostSignalPage<T>(T viewModel, Widget page) =>
    Provider<T>.value(value: viewModel, child: hostShell(page));

// The same shell for a widget that needs the app's theme and a navigator but no
// view model — a dialog, say. A page that reads `context.theme` throws without
// this, so anything pumped bare belongs here.
Widget hostShell(Widget home) =>
    MaterialApp(theme: _theme.themeData, home: home);
