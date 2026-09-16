import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/app/app.dart';
import 'package:flutter_x/provider.dart';
import 'package:injectify/injectify.dart';

void main() {
  setUp(() async {
    // The app resolves its dependencies from the container, so a test that pumps
    // it has to build one first — in `test`, where the posts feature reads its
    // in-memory adapter instead of the network.
    await getIt.reset();
    await configureDependencies(environment: Environment.test);
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

    // The write side, through the container's own dispatcher: the button sends
    // the command, and the line under it is the cart query's answer.
    expect(find.text('0 in cart'), findsOneWidget);
    await tester.tap(find.text('Add to cart'));
    await tester.pumpAndSettle();
    expect(find.text('1 in cart'), findsOneWidget);

    // The cart screen reads the same cart back, through its own query and the
    // view model the container builds for it.
    await tester.tap(find.byTooltip('Cart'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Cart'), findsOneWidget);
    expect(find.text('Espresso cup'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);

    // A back gesture at this depth unwinds one step of the feature's own stack.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('1 in cart'), findsOneWidget);

    // A back gesture at this depth unwinds the feature, not the host stack.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'sku-42'), findsNothing);
    expect(find.text('Espresso cup'), findsOneWidget);

    // At the feature's root the exit action pops the mount off the host stack.
    await tester.tap(find.byTooltip('Exit shop'));
    await tester.pumpAndSettle();
    expect(find.text('kaisel features'), findsOneWidget);

    // The posts feature is the same shape over a different source: in `test` the
    // container binds its in-memory adapter, so this touches no network.
    await tester.tap(find.text('Open posts'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Posts'), findsOneWidget);
    expect(find.text('First post'), findsOneWidget);

    await tester.tap(find.text('First post'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Post 1'), findsOneWidget);
    expect(find.text('The first post in the local fixture.'), findsOneWidget);

    // Back to the list, where the exit action lives.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Posts'), findsOneWidget);

    await tester.tap(find.byTooltip('Exit posts'));
    await tester.pumpAndSettle();
    expect(find.text('kaisel features'), findsOneWidget);
  });
}
