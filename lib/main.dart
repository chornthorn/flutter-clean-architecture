import 'package:flutter/material.dart';

import 'app/app.dart';
import 'provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const KaiselApp());
}
