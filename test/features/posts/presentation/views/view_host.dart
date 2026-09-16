import 'package:flutter/material.dart';
import 'package:flutter_x/core/design_system/app_theme.g.dart';
import 'package:provider/provider.dart';

// One notifier for the whole test run. `themeData` is a getter over immutable
// token maps, so sharing it costs nothing.
final _theme = AppThemeNotifier(initialMode: AppThemeMode.light);

// Puts a page under a provider the way the feature's module does. `.value` hands
// over a view model the test owns — `ChangeNotifierProvider.value` has no
// dispose callback, so the provider will not dispose it.
//
// The `MaterialApp` carries the app's token theme, because the app's does: a page
// that reads `context.theme` renders here as it does in the app.
Widget hostPage<T extends ChangeNotifier>(T viewModel, Widget page) =>
    ChangeNotifierProvider<T>.value(
      value: viewModel,
      child: MaterialApp(theme: _theme.themeData, home: page),
    );
