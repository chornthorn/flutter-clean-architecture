import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Puts a page under a provider the way the feature's module does. `.value` hands
// over a view model the test owns — `ChangeNotifierProvider.value` has no
// dispose callback, so the provider will not dispose it.
Widget hostPage<T extends ChangeNotifier>(T viewModel, Widget page) =>
    ChangeNotifierProvider<T>.value(
      value: viewModel,
      child: MaterialApp(home: page),
    );
