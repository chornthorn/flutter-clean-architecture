import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/core/presentation/action_result.dart';
import 'package:flutter_x/features/posts/presentation/widgets/post_form_dialog.dart';

import '../../../../app/view_host.dart';

void main() {
  // Opens the dialog the way a page does, over a live navigator.
  Future<void> openDialog(
    WidgetTester tester,
    Future<ActionResult> Function(String title, String body) onSubmit, {
    String heading = 'New post',
    String submitLabel = 'Create',
    String initialTitle = '',
    String initialBody = '',
  }) async {
    await tester.pumpWidget(
      hostShell(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => PostFormDialog(
                  heading: heading,
                  submitLabel: submitLabel,
                  initialTitle: initialTitle,
                  initialBody: initialBody,
                  onSubmit: onSubmit,
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('PostFormDialog', () {
    testWidgets('should not offer to submit a post with no title', (
      tester,
    ) async {
      await openDialog(
        tester,
        (title, body) async => const ActionResult.success(),
      );

      final submit = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Create'),
      );

      expect(submit.onPressed, isNull);
    });

    testWidgets('should start an edit filled in and ready to save', (
      tester,
    ) async {
      await openDialog(
        tester,
        (title, body) async => const ActionResult.success(),
        heading: 'Edit post',
        submitLabel: 'Save',
        initialTitle: 'First post',
        initialBody: 'The first post in the local fixture.',
      );

      expect(find.text('Edit post'), findsOneWidget);
      expect(find.text('First post'), findsOneWidget);
      expect(find.text('The first post in the local fixture.'), findsOneWidget);

      // A prefilled title is a title: no need to retype it before saving.
      final submit = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save'),
      );
      expect(submit.onPressed, isNotNull);
    });

    testWidgets('should hand over what was typed and close', (tester) async {
      String? sentTitle;
      String? sentBody;
      await openDialog(tester, (title, body) async {
        sentTitle = title;
        sentBody = body;
        return const ActionResult.success();
      });

      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'A title',
      );
      await tester.enterText(find.widgetWithText(TextField, 'Body'), 'A body');
      await tester.pump();

      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(sentTitle, 'A title');
      expect(sentBody, 'A body');
      expect(find.byType(PostFormDialog), findsNothing);
    });

    testWidgets('should stay open and say so when the write fails', (
      tester,
    ) async {
      await openDialog(
        tester,
        (title, body) async =>
            const ActionResult.failure('Could not save the post.'),
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'A title',
      );
      await tester.pump();

      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      // Staying open is the point: the typed post is not lost.
      expect(find.byType(PostFormDialog), findsOneWidget);
      expect(find.text('Could not save the post.'), findsOneWidget);
      expect(find.text('A title'), findsOneWidget);
    });

    testWidgets(
      'should validate title on user interaction live when typing less than 5 characters',
      (tester) async {
        bool submitCalled = false;
        await openDialog(tester, (title, body) async {
          submitCalled = true;
          return const ActionResult.success();
        });

        // Initially no error
        expect(find.text('Title must be at least 5 characters.'), findsNothing);

        // User types single character 'c' -> autovalidateMode.onUserInteraction triggers live
        await tester.enterText(find.widgetWithText(TextField, 'Title'), 'c');
        await tester.pump();

        expect(
          find.text('Title must be at least 5 characters.'),
          findsOneWidget,
        );

        // User taps Create -> blocked by client validation
        await tester.tap(find.text('Create'));
        await tester.pump();
        expect(submitCalled, isFalse);

        // User types at least 5 characters -> error clears immediately
        await tester.enterText(
          find.widgetWithText(TextField, 'Title'),
          'Valid Title',
        );
        await tester.pump();

        expect(find.text('Title must be at least 5 characters.'), findsNothing);

        // Now Create succeeds
        await tester.tap(find.text('Create'));
        await tester.pumpAndSettle();
        expect(submitCalled, isTrue);
      },
    );
  });
}
