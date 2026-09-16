import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/app.dart';
import 'package:flutter_application_1/core/design_system/app_theme.g.dart';
import 'package:flutter_application_1/dependency_container.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async {
    await getIt.reset();
    await configureDependencies();
  });

  testWidgets('should hand the token theme to the screens', (tester) async {
    await tester.pumpWidget(const KaiselApp());
    await tester.pumpAndSettle();

    // `context.theme` throws when no AppTheme is in the theme, so reading a
    // token here is also the assertion that the extension was attached.
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

    // Both halves move: Material's brightness and the token values behind it.
    expect(Theme.of(_context(tester)).brightness, Brightness.dark);
    expect(
      _context(tester).theme.colors.canvas.primary,
      const Color(0xFF111827),
    );
  });
}

// The landing screen's title sits below `MaterialApp`, so its context sees the
// theme the app handed down.
BuildContext _context(WidgetTester tester) =>
    tester.element(find.text('kaisel features'));
