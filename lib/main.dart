import 'package:flutter/material.dart';
import 'package:injectify/injectify.dart';

import 'app/app.dart';
import 'provider.dart';
  
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // `DI_ENV=dev` swaps the posts source from HTTP to the in-memory fixtures.
  await configureDependencies(
    environment: const String.fromEnvironment(
      'DI_ENV',
      defaultValue: Environment.prod,
    ),
  );

  runApp(const KaiselApp());
}
