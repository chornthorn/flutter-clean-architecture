import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/core/presentation/action_result.dart';
import 'package:flutter_x/core/presentation/form/app_form_controller.dart';
import 'package:flutter_x/features/posts/presentation/widgets/comment_form_dialog.dart';

import '../../../../app/view_host.dart';

void main() {
  // Opens the dialog the way a page does, over a live navigator.
  Future<void> openDialog(
    WidgetTester tester,
    Future<ActionResult> Function(AppFormController form) onSubmit, {
    AppFormController? formController,
  }) async {
    final effectiveController = formController ?? AppFormController();
    addTearDown(() {
      if (formController == null) {
        effectiveController.dispose();
      }
    });

    await tester.pumpWidget(
      hostShell(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => CommentFormDialog(
                  formController: effectiveController,
                  onSubmit: () => onSubmit(effectiveController),
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

  Future<void> fillForm(
    WidgetTester tester, {
    String name = 'Ada Lovelace',
    String email = 'ada@example.com',
    String body = 'A new comment',
  }) async {
    await tester.enterText(find.widgetWithText(TextField, 'Name'), name);
    await tester.enterText(find.widgetWithText(TextField, 'Email'), email);
    await tester.enterText(find.widgetWithText(TextField, 'Body'), body);
    await tester.pump();
  }

  group('CommentFormDialog', () {
    testWidgets('should not offer to submit a comment that is still empty', (
      tester,
    ) async {
      await openDialog(tester, (form) async => const ActionResult.success());

      final submit = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Add'),
      );

      expect(submit.onPressed, isNull);
    });

    testWidgets('should gate submit on the whole form, not on one good field', (
      tester,
    ) async {
      await openDialog(tester, (form) async => const ActionResult.success());

      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'Ada Lovelace',
      );
      await tester.pump();

      // A name is not a comment: the email and the body are still empty.
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Add'))
            .onPressed,
        isNull,
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Email'),
        'ada.example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Body'),
        'A new comment',
      );
      await tester.pump();

      // A filled-in address is not a usable one either.
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Add'))
            .onPressed,
        isNull,
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Email'),
        'ada@example.com',
      );
      await tester.pump();

      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Add'))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('should hand over what was typed and close', (tester) async {
      String? sentName;
      String? sentEmail;
      String? sentBody;
      await openDialog(tester, (form) async {
        sentName = form.text(const FormFieldKey(CommentFormField.name));
        sentEmail = form.text(const FormFieldKey(CommentFormField.email));
        sentBody = form.text(const FormFieldKey(CommentFormField.body));
        return const ActionResult.success();
      });

      await fillForm(tester);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(sentName, 'Ada Lovelace');
      expect(sentEmail, 'ada@example.com');
      expect(sentBody, 'A new comment');
      expect(find.byType(CommentFormDialog), findsNothing);
    });

    testWidgets('should stay open and say so when the write fails', (
      tester,
    ) async {
      await openDialog(
        tester,
        (form) async => const ActionResult.failure('Could not add comment.'),
      );

      await fillForm(tester);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      // Staying open is the point: the typed comment is not lost.
      expect(find.byType(CommentFormDialog), findsOneWidget);
      expect(find.text('Could not add comment.'), findsOneWidget);
      expect(find.text('A new comment'), findsOneWidget);
    });

    testWidgets('should show the field error the server sent', (tester) async {
      final form = AppFormController();
      addTearDown(form.dispose);

      await openDialog(tester, (formCtrl) async {
        return const ActionResult.failure(
          'Server validation failed',
          fieldErrors: {'email': 'Server says that address is taken'},
        );
      }, formController: form);

      await fillForm(tester);
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Server says that address is taken'), findsOneWidget);
    });
  });
}
