import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/core/design_system/components/app_text_field.dart';
import 'package:flutter_x/core/presentation/action_result.dart';
import 'package:flutter_x/core/presentation/form/form_error_controller.dart';
import 'package:flutter_x/core/presentation/form/form_error_scope.dart';

import '../../../app/view_host.dart';

void main() {
  group('FormErrorScope & AppTextField', () {
    testWidgets('should provide FormErrorController down the tree', (
      tester,
    ) async {
      final controller = FormErrorController();
      FormErrorController? resolvedController;

      await tester.pumpWidget(
        hostShell(
          FormErrorScope(
            controller: controller,
            child: Builder(
              builder: (context) {
                resolvedController = FormErrorScope.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(resolvedController, same(controller));
    });

    testWidgets(
      'should display field error when fieldKey matches in FormErrorScope',
      (tester) async {
        final controller = FormErrorController();

        await tester.pumpWidget(
          hostShell(
            FormErrorScope(
              controller: controller,
              child: Scaffold(
                body: AppTextField(
                  fieldKey: 'title',
                  label: 'Title',
                ),
              ),
            ),
          ),
        );

        // Initially no error is shown
        expect(find.text('Title must be unique'), findsNothing);

        // Set error in controller
        controller.setField('title', 'Title must be unique');
        await tester.pump();

        expect(find.text('Title must be unique'), findsOneWidget);
      },
    );

    testWidgets('should clear field error as soon as user types into field', (
      tester,
    ) async {
      final controller = FormErrorController();

      await tester.pumpWidget(
        hostShell(
          FormErrorScope(
            controller: controller,
            child: Scaffold(
              body: AppTextField(
                fieldKey: 'title',
                label: 'Title',
              ),
            ),
          ),
        ),
      );

      controller.bind(
        const ActionFailure(
          'Validation failed',
          fieldErrors: {'title': 'Title is invalid'},
        ),
      );
      await tester.pump();

      expect(find.text('Title is invalid'), findsOneWidget);
      expect(controller['title'], 'Title is invalid');

      // User types into the field -> error must clear immediately
      await tester.enterText(find.byType(TextField), 'My new title');
      await tester.pump();

      expect(find.text('Title is invalid'), findsNothing);
      expect(controller['title'], isNull);
    });

    testWidgets(
      'should isolate multiple forms on one screen with independent error scopes',
      (tester) async {
        final formA = FormErrorController();
        final formB = FormErrorController();

        await tester.pumpWidget(
          hostShell(
            Scaffold(
              body: Column(
                children: [
                  FormErrorScope(
                    controller: formA,
                    child: AppTextField(
                      key: const Key('form_a_email'),
                      fieldKey: 'email',
                      label: 'Form A Email',
                    ),
                  ),
                  FormErrorScope(
                    controller: formB,
                    child: AppTextField(
                      key: const Key('form_b_email'),
                      fieldKey: 'email',
                      label: 'Form B Email',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        // Set error only on Form A
        formA.setField('email', 'Email taken in Form A');
        await tester.pump();

        expect(find.text('Email taken in Form A'), findsOneWidget);
        expect(formA['email'], 'Email taken in Form A');
        expect(formB['email'], isNull);

        // User edits Form B -> does NOT affect Form A
        await tester.enterText(
          find.byKey(const Key('form_b_email')),
          'other@example.com',
        );
        await tester.pump();

        expect(find.text('Email taken in Form A'), findsOneWidget);
        expect(formA['email'], 'Email taken in Form A');

        // User edits Form A -> clears Form A
        await tester.enterText(
          find.byKey(const Key('form_a_email')),
          'mine@example.com',
        );
        await tester.pump();

        expect(find.text('Email taken in Form A'), findsNothing);
        expect(formA['email'], isNull);
      },
    );

    testWidgets('should respect explicit errorText override over scope', (
      tester,
    ) async {
      final controller = FormErrorController();
      controller.setField('username', 'Server error');

      await tester.pumpWidget(
        hostShell(
          FormErrorScope(
            controller: controller,
            child: Scaffold(
              body: AppTextField(
                fieldKey: 'username',
                errorText: 'Explicit local error',
              ),
            ),
          ),
        ),
      );

      // Explicit errorText should take precedence over server error
      expect(find.text('Explicit local error'), findsOneWidget);
      expect(find.text('Server error'), findsNothing);
    });
  });
}
