#### Option B: `@KaiselInit` Annotation (Similar to `@InjectableInit` / `@CqrsInit`)

Decouple route configuration completely from your UI/Widget tree by annotating a top-level function or configuration entry point (e.g. in `lib/app/app.dart`):

```dart
import 'package:flutter/material.dart';
import 'package:kaisel/kaisel.dart';
import 'package:kaisel_generator/kaisel_generator.dart';

import 'app_modules.g.dart';

export 'app_modules.g.dart';

// Decoupled routing entry point
@KaiselInit()
void configureRouting() {}

// The app's router, configured from the generated module registry.
final appRouterConfig = defaultAppRouterConfig;

// Your Widget tree stays 100% standard Flutter and decoupled from annotations
class KaiselApp extends StatelessWidget {
  const KaiselApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: appRouterConfig,
    );
  }
}
```
