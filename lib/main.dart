import 'package:flutter/material.dart';
import 'package:injectify/injectify.dart';

import 'app/app.dart';
import 'provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Which adapter each environment-gated binding gets rolled in with: `prod`
  // reads jsonplaceholder over HTTP, `dev`/`test` read the in-memory posts.
  // Override with `flutter run --dart-define=DI_ENV=dev`.
  await configureDependencies(
    environment: const String.fromEnvironment(
      'DI_ENV',
      defaultValue: Environment.prod,
    ),
  );

  runApp(const KaiselApp());
}
