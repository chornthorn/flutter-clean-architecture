import 'package:flutter/material.dart';
import 'package:flutter_x/core/design_system/app_theme.g.dart';
import 'package:provider/provider.dart';

// One notifier for the test run: `themeData` is a getter over immutable token maps.
final _theme = AppThemeNotifier(initialMode: AppThemeMode.light);

// Pumps a page as the app runs it: the app's theme, the route's provider.
// No dispose callback on `.value`: the test keeps owning the view model.
Widget hostSignalPage<T>(T viewModel, Widget page) =>
    Provider<T>.value(value: viewModel, child: hostShell(page));

// The same shell without a view model, for a widget that needs only the theme.
Widget hostShell(Widget home) =>
    MaterialApp(theme: _theme.themeData, home: home);
