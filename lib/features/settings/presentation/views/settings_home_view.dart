import 'package:flutter/material.dart';
import 'package:kaisel/kaisel.dart';

import '../../../../app/app.dart';
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
        IconButton(
          onPressed: () => context.router<AppRoute>().pop(),
          icon: const Icon(Icons.close),
          tooltip: 'Exit settings',
        ),
      ],
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: EdgeInsets.all(theme.sizes.padding.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppOutlinedButton(
                  label: 'About this demo',
                  onPressed: () => context.push(const SettingsAbout()),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
