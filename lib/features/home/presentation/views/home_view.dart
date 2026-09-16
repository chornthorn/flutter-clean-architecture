import 'package:flutter/material.dart';
import 'package:kaisel/kaisel.dart';

import '../../../../app/app_route.dart';
import '../../../../core/design_system/app_theme.g.dart';

// The app's landing screen. Each button pushes a mount marker; the feature
// behind it supplies the screens from there.
class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('kaisel features'),
        actions: [
          // Exercises the other token set; drop it once the pipeline is trusted.
          IconButton(
            tooltip: 'Toggle theme',
            icon: const Icon(Icons.brightness_6),
            onPressed: context.themeNotifier.toggleMode,
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FilledButton(
              onPressed: () => context.push(const ShopMount()),
              child: const Text('Open shop'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => context.push(const SettingsMount()),
              child: const Text('Open settings'),
            ),
          ],
        ),
      ),
    );
  }
}
