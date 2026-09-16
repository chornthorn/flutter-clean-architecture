import 'package:flutter/material.dart';
import 'package:flutter_application_1/app/app.dart';
import 'package:flutter_application_1/provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async {
    // The app resolves its dependencies from the container, so a test that pumps
    // it has to build one first.
    await getIt.reset();
    await configureDependencies();
  });

  testWidgets('should navigate into a feature, within it, and back out', (
    tester,
  ) async {
    await tester.pumpWidget(const KaiselApp());
    await tester.pumpAndSettle();

    expect(find.text('kaisel features'), findsOneWidget);

    // Host stack: [HomeMount, ShopMount] — the feature supplies the screens.
    await tester.tap(find.text('Open shop'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Shop'), findsOneWidget);

    // The list arrives through the domain contract and the real in-memory
    // adapter wired at the composition root.
    expect(find.text('Espresso cup'), findsOneWidget);

    // Pushed on the feature's own router, not the host's. The product view
    // titles itself with the route's id and shows the domain entity.
    await tester.tap(find.text('Espresso cup'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'sku-42'), findsOneWidget);
    expect(find.text('12.50'), findsOneWidget);

    // A back gesture at this depth unwinds the feature, not the host stack.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'sku-42'), findsNothing);
    expect(find.text('Espresso cup'), findsOneWidget);

    // At the feature's root the exit action pops the mount off the host stack.
    await tester.tap(find.byTooltip('Exit shop'));
    await tester.pumpAndSettle();
    expect(find.text('kaisel features'), findsOneWidget);
  });
}
