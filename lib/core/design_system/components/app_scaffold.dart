import 'package:flutter/material.dart';

import '../app_theme.g.dart';

// A screen's chrome: canvas, bar and floating action, all from tokens.
//
// Every screen goes through here so a bar cannot be one colour on a page and
// another on the next — which is what happens when each screen builds its own
// `AppBar` and Material fills in the rest from the generated scheme.
//
// The bar takes its title the way a standard `AppBar` does, widget and all, so
// a screen that needs a row, a tab strip or a second line in the title can still
// say so. What it does not take is the styling: that stays here.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions = const [],
    this.floatingActionButton,
  });

  final Widget body;

  // Styled by the bar's `titleTextStyle`; give the widget its own style when a
  // screen needs to say something different.
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
        // The bar is a fixed token colour, and Material's scroll tint would
        // paint the generated scheme's colour over it.
        surfaceTintColor: Colors.transparent,
        actions: actions,
      ),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}
