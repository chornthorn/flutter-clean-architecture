import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/core/design_system/components/app_text_field.dart';
import 'package:flutter_x/core/presentation/action_result.dart';
import 'package:flutter_x/core/presentation/form/app_form_controller.dart';
import 'package:flutter_x/core/presentation/form/app_form_provider.dart';

import '../../../app/view_host.dart';

enum _TestField with FormFieldKeyMixin { title }

void main() {
  group('AppFormProvider & AppTextField', () {
    const titleKey = FormFieldKey(_TestField.title);

    testWidgets('should provide AppFormController down the tree', (
      tester,
    ) async {
      final controller = AppFormController();
      AppFormController? resolvedController;

      await tester.pumpWidget(
        hostShell(
          AppFormProvider(
            controller: controller,
            child: Builder(
              builder: (context) {
                resolvedController = AppFormProvider.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(resolvedController, same(controller));
    });

    testWidgets(
      'should display field error when fieldKey matches in AppFormProvider',
      (tester) async {
        final controller = AppFormController();

        await tester.pumpWidget(
          hostShell(
            AppFormProvider(
              controller: controller,
              child: const Scaffold(
                body: AppTextField(fieldKey: titleKey, label: 'Title'),
              ),
            ),
          ),
        );

        expect(find.text('Title must not be empty'), findsNothing);

        // Bind failure with matching field error
        controller.bind(
          const ActionFailure(
            'Validation failed',
            fieldErrors: {'title': 'Title must not be empty'},
          ),
        );
        await tester.pump();

        expect(find.text('Title must not be empty'), findsOneWidget);
      },
    );

    testWidgets('should clear field error as soon as user types into field', (
      tester,
    ) async {
      final controller = AppFormController();

      await tester.pumpWidget(
        hostShell(
          AppFormProvider(
            controller: controller,
            child: const Scaffold(
              body: AppTextField(fieldKey: titleKey, label: 'Title'),
            ),
          ),
        ),
      );

      controller.setField(titleKey, 'Server error');
      await tester.pump();
      expect(find.text('Server error'), findsOneWidget);

      // Type into the field -> error is cleared immediately
      await tester.enterText(find.byType(TextField), 'New post title');
      await tester.pump();

      expect(find.text('Server error'), findsNothing);
      expect(controller[titleKey], isNull);
    });

    testWidgets(
      'should isolate multiple forms on one screen with independent form providers',
      (tester) async {
        final formA = AppFormController();
        final formB = AppFormController();

        await tester.pumpWidget(
          hostShell(
            Scaffold(
              body: Column(
                children: [
                  AppFormProvider(
                    controller: formA,
                    child: const AppTextField(
                      key: Key('field_a'),
                      fieldKey: titleKey,
                      label: 'Form A Title',
                    ),
                  ),
                  AppFormProvider(
                    controller: formB,
                    child: const AppTextField(
                      key: Key('field_b'),
                      fieldKey: titleKey,
                      label: 'Form B Title',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        // Form A error does not affect Form B
        formA.setField(titleKey, 'Form A Error');
        await tester.pump();

        expect(find.text('Form A Error'), findsOneWidget);
        expect(formA[titleKey], 'Form A Error');
        expect(formB[titleKey], isNull);

        // Typing in Form B does not clear Form A's error
        await tester.enterText(
          find.byKey(const Key('field_b')),
          'Hello from Form B',
        );
        await tester.pump();

        expect(find.text('Form A Error'), findsOneWidget);
        expect(formA[titleKey], 'Form A Error');

        // Typing in Form A clears Form A's error
        await tester.enterText(
          find.byKey(const Key('field_a')),
          'Hello from Form A',
        );
        await tester.pump();

        expect(find.text('Form A Error'), findsNothing);
        expect(formA[titleKey], isNull);
      },
    );

    testWidgets('should respect explicit errorText override over scope', (
      tester,
    ) async {
      final controller = AppFormController();
      controller.setField(titleKey, 'Scoped error');

      await tester.pumpWidget(
        hostShell(
          AppFormProvider(
            controller: controller,
            child: const Scaffold(
              body: AppTextField(
                fieldKey: titleKey,
                label: 'Title',
                errorText: 'Explicit override',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Explicit override'), findsOneWidget);
      expect(find.text('Scoped error'), findsNothing);
    });
  });
}
