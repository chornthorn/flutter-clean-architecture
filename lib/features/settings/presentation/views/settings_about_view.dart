import 'package:flutter/material.dart';

import '../../../../core/design_system/app_theme.g.dart';
import '../../../../core/design_system/components/app_scaffold.dart';

// Pushed inside the feature.
class SettingsAboutView extends StatelessWidget {
  const SettingsAboutView({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: const Text('About'),
      body: Center(
        child: Text(
          'About this app',
          style: context.theme.typography.body.regular,
        ),
      ),
    );
  }
}
