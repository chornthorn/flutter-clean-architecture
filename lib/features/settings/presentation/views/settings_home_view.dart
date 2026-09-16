import 'package:flutter/material.dart';
import 'package:kaisel/kaisel.dart';

import '../../../../app/app_route.dart';
import '../../../../core/design_system/app_theme.g.dart';
import '../../../../core/design_system/components/app_buttons.dart';
import '../../../../core/design_system/components/app_scaffold.dart';
import '../../settings_module.dart';

// The feature's root screen.
class SettingsHomeView extends StatelessWidget {
  const SettingsHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return AppScaffold(
      title: const Text('Settings'),
      actions: [
        // The inner navigator is at its root, so this pops the host stack.
        IconButton(
          onPressed: () => context.router<AppRoute>().pop(),
          icon: const Icon(Icons.close),
          tooltip: 'Exit settings',
        ),
      ],
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Settings home', style: theme.typography.body.regular),
            SizedBox(height: theme.sizes.spacing.md),
            AppFilledButton(
              label: 'About',
              onPressed: () => context.push(const SettingsAbout()),
            ),
          ],
        ),
      ),
    );
  }
}
