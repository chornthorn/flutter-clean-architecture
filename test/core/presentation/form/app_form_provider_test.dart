import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/core/design_system/components/app_text_field.dart';
import 'package:flutter_x/core/presentation/action_result.dart';
import 'package:flutter_x/core/presentation/form/app_form_provider.dart';

import '../../../app/view_host.dart';

enum _TestField with FormFieldKeyMixin { title }

void main() {
  group('AppFormProvider & AppTextField', () {
    const titleKey = FormFieldKey(_TestField.title);

    testWidgets('should render with no server error initially', (tester) async {
      final controller = AppFormController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        hostShell(
          Scaffold(
            body: AppFormProvider(
              controller: controller,
              child: const AppTextField(fieldKey: titleKey, label: 'Title'),
            ),
          ),
        ),
      );

      expect(find.text('Title'), findsOneWidget);
      // No error text rendered initially
      expect(find.text('Title is required'), findsNothing);
    });

    testWidgets(
      'should display server error when controller receives error for field',
      (tester) async {
        final controller = AppFormController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          hostShell(
            Scaffold(
              body: AppFormProvider(
                controller: controller,
                child: const AppTextField(fieldKey: titleKey, label: 'Title'),
              ),
            ),
          ),
        );

        // Bind an action failure with field error
        controller.bind(
          const ActionResult.failure(
            'Validation failed',
            fieldErrors: {'title': 'Title is required'},
          ),
        );
        await tester.pump();

        expect(find.text('Title is required'), findsOneWidget);
      },
    );

    testWidgets('should clear server error when text changes in AppTextField', (
      tester,
    ) async {
      final controller = AppFormController();
      addTearDown(controller.dispose);

      controller.setField(titleKey, 'Invalid title');

      await tester.pumpWidget(
        hostShell(
          Scaffold(
            body: AppFormProvider(
              controller: controller,
              child: const AppTextField(fieldKey: titleKey, label: 'Title'),
            ),
          ),
        ),
      );

      expect(find.text('Invalid title'), findsOneWidget);

      // User types in the field -> should auto-clear the error
      await tester.enterText(find.byType(TextField), 'Valid title');
      await tester.pump();

      expect(find.text('Invalid title'), findsNothing);
      expect(controller.hasField(titleKey), isFalse);
    });

    testWidgets(
      'should automatically bind managed TextEditingController and sync values with controller and signal',
      (tester) async {
        final formController = AppFormController.fromValues({
          _TestField.title: 'Initial text',
        });
        addTearDown(formController.dispose);

        await tester.pumpWidget(
          hostShell(
            Scaffold(
              body: AppFormProvider(
                controller: formController,
                child: const AppTextField(fieldKey: titleKey, label: 'Title'),
              ),
            ),
          ),
        );

        // Check initial text rendered in TextField
        expect(find.text('Initial text'), findsOneWidget);

        // User types new text
        await tester.enterText(find.byType(TextField), 'Typed text');
        await tester.pump();

        expect(formController.text(titleKey), 'Typed text');
        expect(formController.signal(titleKey).value, 'Typed text');

        // Programmatic change from formController
        formController.setValue(titleKey, 'Programmatic text');
        await tester.pump();

        expect(find.text('Programmatic text'), findsOneWidget);
      },
    );
  });
}
