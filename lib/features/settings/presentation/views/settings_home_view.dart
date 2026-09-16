import 'package:flutter/material.dart';
import 'package:kaisel/kaisel.dart';

import '../../../../app/app_route.dart';
import '../../settings_module.dart';

// The feature's root screen.
class SettingsHomeView extends StatelessWidget {
  const SettingsHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          // The feature's inner navigator has nothing to pop here, so this
          // leaves the feature.
          IconButton(
            onPressed: () => context.router<AppRoute>().pop(),
            icon: const Icon(Icons.close),
            tooltip: 'Exit settings',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Settings home'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.push(const SettingsAbout()),
              child: const Text('About'),
            ),
          ],
        ),
      ),
    );
  }
}
