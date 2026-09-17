import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/core/design_system/components/app_text_field.dart';
import 'package:flutter_x/core/presentation/form/app_form_controller.dart';
import 'package:flutter_x/core/presentation/form/app_form_scope.dart';

import '../../../app/view_host.dart';

void main() {
  group('AppFormScope', () {
    testWidgets('should delegate all options to Flutter Form', (tester) async {
      final formKey = GlobalKey<FormState>();
      var onChangedCalled = false;

      await tester.pumpWidget(
        hostShell(
          AppFormScope(
            options: AppFormOptions(
              key: formKey,
              onChanged: () => onChangedCalled = true,
              autovalidateMode: AutovalidateMode.disabled,
            ),
            child: Scaffold(
              body: AppTextField(
                fieldKey: 'test',
                label: 'Test',
                validator: (val) => val == 'invalid' ? 'Error' : null,
              ),
            ),
          ),
        ),
      );

      expect(formKey.currentState, isNotNull);

      // Typing triggers onChanged
      await tester.enterText(find.byType(TextField), 'hello');
      await tester.pump();
      expect(onChangedCalled, isTrue);

      // Explicit validate via FormState works
      await tester.enterText(find.byType(TextField), 'invalid');
      await tester.pump();
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Error'), findsOneWidget);
    });

    testWidgets(
      'should autovalidate AppTextField immediately when autovalidateMode is always',
      (tester) async {
        await tester.pumpWidget(
          hostShell(
            AppFormScope(
              options: const AppFormOptions(
                autovalidateMode: AutovalidateMode.always,
              ),
              child: Scaffold(
                body: AppTextField(
                  fieldKey: 'title',
                  label: 'Title',
                  validator: (value) => (value == null || value.length < 5)
                      ? 'Title must be at least 5 characters'
                      : null,
                ),
              ),
            ),
          ),
        );

        // Without any clicks or edits, autovalidateMode.always shows the error immediately
        expect(
          find.text('Title must be at least 5 characters'),
          findsOneWidget,
        );

        // Typing valid characters clears the error
        await tester.enterText(find.byType(TextField), 'Hello World');
        await tester.pump();
        expect(find.text('Title must be at least 5 characters'), findsNothing);
      },
    );

    testWidgets(
      'should autovalidate AppTextField on user interaction when autovalidateMode is onUserInteraction',
      (tester) async {
        await tester.pumpWidget(
          hostShell(
            AppFormScope(
              options: const AppFormOptions(
                autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              child: Scaffold(
                body: AppTextField(
                  fieldKey: 'title',
                  label: 'Title',
                  validator: (value) => (value == null || value.length < 5)
                      ? 'Title must be at least 5 characters'
                      : null,
                ),
              ),
            ),
          ),
        );

        // On initial render, no error is shown yet
        expect(find.text('Title must be at least 5 characters'), findsNothing);

        // As soon as user interacts/types, it validates live
        await tester.enterText(find.byType(TextField), 'Hi');
        await tester.pump();
        expect(
          find.text('Title must be at least 5 characters'),
          findsOneWidget,
        );

        // Once user reaches 5 characters, error clears live
        await tester.enterText(find.byType(TextField), 'Hello');
        await tester.pump();
        expect(find.text('Title must be at least 5 characters'), findsNothing);
      },
    );

    testWidgets('should prioritize client validator over server error', (
      tester,
    ) async {
      final controller = AppFormController();

      await tester.pumpWidget(
        hostShell(
          AppFormScope(
            controller: controller,
            child: Scaffold(
              body: AppTextField(
                fieldKey: 'email',
                label: 'Email',
                validator: (value) => (value == null || !value.contains('@'))
                    ? 'Invalid email format'
                    : null,
              ),
            ),
          ),
        ),
      );

      // Server returns error
      controller.setField('email', 'Email is already taken on server');
      await tester.pump();
      expect(find.text('Email is already taken on server'), findsOneWidget);

      // User types invalid client input -> client validator takes precedence
      await tester.enterText(find.byType(TextField), 'bademail');
      final form = tester.state<FormState>(find.byType(Form));
      form.validate();
      await tester.pump();

      expect(find.text('Invalid email format'), findsOneWidget);
      expect(find.text('Email is already taken on server'), findsNothing);
    });

    testWidgets('should provide FormState via AppFormScope.of(context)', (
      tester,
    ) async {
      FormState? captured;

      await tester.pumpWidget(
        hostShell(
          AppFormScope(
            child: Builder(
              builder: (context) {
                captured = AppFormScope.of(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(captured, isNotNull);
    });

    testWidgets(
      'should bind controller.formKey and allow validate, save, and reset via AppFormController instance',
      (tester) async {
        final controller = AppFormController();
        String? savedValue;

        await tester.pumpWidget(
          hostShell(
            AppFormScope(
              controller: controller,
              child: Scaffold(
                body: AppTextField(
                  fieldKey: 'name',
                  label: 'Name',
                  validator: (val) =>
                      (val == null || val.isEmpty) ? 'Required' : null,
                  onSaved: (val) => savedValue = val,
                ),
              ),
            ),
          ),
        );

        // controller.formKey is automatically bound to FormState
        expect(controller.formState, isNotNull);
        expect(controller.validate(), isFalse);
        await tester.pump();
        expect(find.text('Required'), findsOneWidget);

        // Enter valid text
        await tester.enterText(find.byType(TextField), 'John');
        await tester.pump();

        // validate() now succeeds
        expect(controller.validate(), isTrue);
        await tester.pump();
        expect(find.text('Required'), findsNothing);

        // save() calls onSaved
        controller.save();
        expect(savedValue, 'John');

        // set server error and reset()
        controller.setField('name', 'Server issue');
        await tester.pump();
        expect(find.text('Server issue'), findsOneWidget);

        controller.reset();
        await tester.pump();
        // reset() clears both form fields and server errors
        expect(find.text('Server issue'), findsNothing);
        expect(controller.hasErrors, isFalse);
      },
    );

    testWidgets(
      'should isolate multiple forms on one screen with independent keys and form providers',
      (tester) async {
        final controllerA = AppFormController();
        final controllerB = AppFormController();

        await tester.pumpWidget(
          hostShell(
            Scaffold(
              body: Column(
                children: [
                  AppFormScope(
                    controller: controllerA,
                    child: AppTextField(
                      key: const Key('field_a'),
                      fieldKey: 'code',
                      label: 'Form A Code',
                    ),
                  ),
                  AppFormScope(
                    controller: controllerB,
                    child: AppTextField(
                      key: const Key('field_b'),
                      fieldKey: 'code',
                      label: 'Form B Code',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        // Form keys from each controller are automatically distinct
        expect(controllerA.formState, isNotNull);
        expect(controllerB.formState, isNotNull);
        expect(controllerA.formState, isNot(same(controllerB.formState)));

        // Error in Form A does not affect Form B
        controllerA.setField('code', 'Invalid code in Form A');
        await tester.pump();

        expect(find.text('Invalid code in Form A'), findsOneWidget);
        expect(controllerA['code'], 'Invalid code in Form A');
        expect(controllerB['code'], isNull);

        // Editing Form B does not clear Form A
        await tester.enterText(find.byKey(const Key('field_b')), '999');
        await tester.pump();

        expect(find.text('Invalid code in Form A'), findsOneWidget);
        expect(controllerA['code'], 'Invalid code in Form A');

        // Editing Form A clears only Form A
        await tester.enterText(find.byKey(const Key('field_a')), '123');
        await tester.pump();

        expect(find.text('Invalid code in Form A'), findsNothing);
        expect(controllerA['code'], isNull);
      },
    );

    testWidgets('should manage internal AppFormController if none provided', (
      tester,
    ) async {
      AppFormController? resolvedController;

      await tester.pumpWidget(
        hostShell(
          AppFormScope(
            child: Builder(
              builder: (context) {
                resolvedController = AppFormScope.controllerOf(context);
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(resolvedController, isNotNull);
      expect(resolvedController!.hasErrors, isFalse);
    });
  });
}
