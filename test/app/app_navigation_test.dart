import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/app/app.dart';
import 'package:flutter_x/provider.dart';
import 'package:injectify/injectify.dart';

void main() {
  setUp(() async {
    await getIt.reset();
    await configureDependencies(environment: Environment.test);
  });

  testWidgets('should navigate into a feature, within it, and back out', (
    tester,
  ) async {
    await tester.pumpWidget(const KaiselApp());
    await tester.pumpAndSettle();

    expect(find.text('kaisel features'), findsOneWidget);

    // Host stack [HomeMount, ShopMount]: the feature supplies the screens.
    await tester.tap(find.text('Open shop'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Shop'), findsOneWidget);

    expect(find.text('Espresso cup'), findsOneWidget);

    await tester.tap(find.text('Espresso cup'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'sku-42'), findsOneWidget);
    expect(find.text('12.50'), findsOneWidget);

    expect(find.text('0 in cart'), findsOneWidget);
    await tester.tap(find.text('Add to cart'));
    await tester.pumpAndSettle();
    expect(find.text('1 in cart'), findsOneWidget);

    await tester.tap(find.byTooltip('Cart'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Cart'), findsOneWidget);
    expect(find.text('Espresso cup'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);

    // Back unwinds the feature's own stack, not the host's.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('1 in cart'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'sku-42'), findsNothing);
    expect(find.text('Espresso cup'), findsOneWidget);

    // At the feature's root the exit action pops the mount off the host stack.
    await tester.tap(find.byTooltip('Exit shop'));
    await tester.pumpAndSettle();
    expect(find.text('kaisel features'), findsOneWidget);

    await tester.tap(find.text('Open posts'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Posts'), findsOneWidget);
    expect(find.text('First post'), findsOneWidget);

    await tester.tap(find.byTooltip('New post'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'Added post',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Body'),
      'Added post body',
    );
    await tester.pump();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('Added post'), findsOneWidget);

    await tester.tap(find.text('First post'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Post 1'), findsOneWidget);
    expect(find.text('The first post in the local fixture.'), findsOneWidget);

    await tester.tap(find.byTooltip('Edit post'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Title'),
      'Edited post',
    );
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Edited post'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Posts'), findsOneWidget);
    expect(find.text('Edited post'), findsOneWidget);
    expect(find.text('First post'), findsNothing);

    await tester.tap(find.text('Edited post'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete post'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this post?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Posts'), findsOneWidget);
    expect(find.text('Edited post'), findsNothing);
    expect(find.text('Added post'), findsOneWidget);

    await tester.tap(find.byTooltip('Exit posts'));
    await tester.pumpAndSettle();
    expect(find.text('kaisel features'), findsOneWidget);
  });
}
