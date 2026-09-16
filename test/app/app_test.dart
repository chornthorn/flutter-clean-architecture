import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/app/app.dart';
import 'package:flutter_x/core/design_system/app_theme.g.dart';
import 'package:flutter_x/provider.dart';
import 'package:injectify/injectify.dart';

void main() {
  setUp(() async {
    await getIt.reset();
    await configureDependencies(environment: Environment.test);
  });

  testWidgets('should hand the token theme to the screens', (tester) async {
    await tester.pumpWidget(const KaiselApp());
    await tester.pumpAndSettle();

    final theme = _context(tester).theme;

    expect(theme.colors.brand.primary, const Color(0xFF4F46E5));
    expect(theme.colors.canvas.primary, const Color(0xFFF9FAFB));
    expect(theme.sizes.spacing.md, 16);
    expect(theme.typography.title.semiBold.fontSize, 20);
    expect(theme.typography.title.semiBold.fontWeight, FontWeight.w600);
  });

  testWidgets('should swap the token set when the mode toggles', (
    tester,
  ) async {
    await tester.pumpWidget(const KaiselApp());
    await tester.pumpAndSettle();

    expect(Theme.of(_context(tester)).brightness, Brightness.light);

    await tester.tap(find.byTooltip('Toggle theme'));
    await tester.pumpAndSettle();

    expect(Theme.of(_context(tester)).brightness, Brightness.dark);
    expect(
      _context(tester).theme.colors.canvas.primary,
      const Color(0xFF111827),
    );
  });
}

// The landing title sits below `MaterialApp`: its context carries the theme.
BuildContext _context(WidgetTester tester) =>
    tester.element(find.text('kaisel features'));
