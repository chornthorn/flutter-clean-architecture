import 'package:flutter/material.dart';

import '../app_theme.g.dart';

// A screen's chrome: canvas, bar and floating action, all from tokens, so a bar
// cannot be one colour here and another on the next screen.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions = const [],
    this.floatingActionButton,
  });

  final Widget body;

  // The bar styles it; give the widget its own style to say something else.
  final Widget? title;

  final List<Widget> actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Scaffold(
      backgroundColor: theme.colors.canvas.primary,
      appBar: AppBar(
        title: title,
        backgroundColor: theme.colors.surface.card,
        foregroundColor: theme.colors.foreground.primary,
        titleTextStyle: theme.typography.title.semiBold,
        elevation: 0,
        // Material's scroll tint would paint the generated scheme over the token.
        surfaceTintColor: Colors.transparent,
        actions: actions,
      ),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}
