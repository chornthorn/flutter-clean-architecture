import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/core/design_system/app_theme.g.dart';
import 'package:flutter_x/core/design_system/components/app_card.dart';
import 'package:flutter_x/features/posts/presentation/widgets/post_tile.dart';

import '../../../../app/view_host.dart';
import '../../domain/entities/post_fixture.dart';

void main() {
  group('PostTile', () {
    testWidgets('should show the title, a snippet and the byline', (
      tester,
    ) async {
      await tester.pumpWidget(hostShell(PostTile(post: post, onTap: () {})));

      expect(find.text('First post'), findsOneWidget);
      // The whole body is the snippet, clipped to two lines by the row.
      expect(find.text('The first post in the local fixture.'), findsOneWidget);
      expect(find.text('by user 1'), findsOneWidget);
    });

    testWidgets('should hand a tap to the page above', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        hostShell(PostTile(post: post, onTap: () => taps++)),
      );

      await tester.tap(find.byType(PostTile));
      await tester.pumpAndSettle();

      expect(taps, 1);
    });

    testWidgets('should paint the card from the tokens', (tester) async {
      late AppTheme theme;
      await tester.pumpWidget(
        hostShell(
          Builder(
            builder: (context) {
              theme = context.theme;
              return PostTile(post: post, onTap: () {});
            },
          ),
        ),
      );

      final card = tester.widget<Material>(
        find.descendant(
          of: find.byType(AppCard),
          matching: find.byType(Material),
        ),
      );

      // The token values, not literals: these are what a mode change swaps.
      expect(card.color, theme.colors.surface.card);
      expect(
        (card.shape! as RoundedRectangleBorder).side.color,
        theme.colors.surface.border,
      );
    });
  });
}
