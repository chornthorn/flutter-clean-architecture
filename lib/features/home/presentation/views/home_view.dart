import 'package:flutter/material.dart';
import 'package:kaisel/kaisel.dart';

import '../../../../app/app.dart';
import '../../../../core/design_system/app_theme.g.dart';
import '../../../../core/design_system/components/app_buttons.dart';
import '../../../../core/design_system/components/app_scaffold.dart';

// The app's landing screen; each button pushes a feature's mount marker.
class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return AppScaffold(
      title: const Text('kaisel features'),
      actions: [
        // Exercises the other token set; drop it once the pipeline is trusted.
        IconButton(
          tooltip: 'Toggle theme',
          icon: const Icon(Icons.brightness_6),
          onPressed: context.themeNotifier.toggleMode,
        ),
      ],
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(theme.sizes.padding.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppFilledButton(
                label: 'Open shop',
                onPressed: () => context.push(const ShopMount()),
              ),
              SizedBox(height: theme.sizes.spacing.sm),
              AppOutlinedButton(
                label: 'Open posts',
                onPressed: () => context.push(const PostsMount()),
              ),
              SizedBox(height: theme.sizes.spacing.sm),
              AppOutlinedButton(
                label: 'Open settings',
                onPressed: () => context.push(const SettingsMount()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
