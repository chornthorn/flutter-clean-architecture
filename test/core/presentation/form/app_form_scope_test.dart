import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/core/design_system/components/app_text_field.dart';
import 'package:flutter_x/core/presentation/form/app_form_scope.dart';

import '../../../app/view_host.dart';

enum _TestScopeField with FormFieldKeyMixin {
  test,
  title,
  email,
  fullName,
  code,
}

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
                fieldKey: const FormFieldKey(_TestScopeField.test),
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
                  fieldKey: const FormFieldKey(_TestScopeField.title),
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
                  fieldKey: const FormFieldKey(_TestScopeField.title),
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
      const emailKey = FormFieldKey(_TestScopeField.email);

      await tester.pumpWidget(
        hostShell(
          AppFormScope(
            controller: controller,
            child: Scaffold(
              body: AppTextField(
                fieldKey: emailKey,
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
      controller.setField(emailKey, 'Email is already taken on server');
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
        const nameKey = FormFieldKey(_TestScopeField.fullName);
        String? savedValue;

        await tester.pumpWidget(
          hostShell(
            AppFormScope(
              controller: controller,
              child: Scaffold(
                body: AppTextField(
                  fieldKey: nameKey,
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
        controller.setField(nameKey, 'Server issue');
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
        const codeKey = FormFieldKey(_TestScopeField.code);

        await tester.pumpWidget(
          hostShell(
            Scaffold(
              body: Column(
                children: [
                  AppFormScope(
                    controller: controllerA,
                    child: const AppTextField(
                      key: Key('field_a'),
                      fieldKey: codeKey,
                      label: 'Form A Code',
                    ),
                  ),
                  AppFormScope(
                    controller: controllerB,
                    child: const AppTextField(
                      key: Key('field_b'),
                      fieldKey: codeKey,
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
        controllerA.setField(codeKey, 'Invalid code in Form A');
        await tester.pump();

        expect(find.text('Invalid code in Form A'), findsOneWidget);
        expect(controllerA[codeKey], 'Invalid code in Form A');
        expect(controllerB[codeKey], isNull);

        // Editing Form B does not clear Form A
        await tester.enterText(find.byKey(const Key('field_b')), '999');
        await tester.pump();

        expect(find.text('Invalid code in Form A'), findsOneWidget);
        expect(controllerA[codeKey], 'Invalid code in Form A');

        // Editing Form A clears only Form A
        await tester.enterText(find.byKey(const Key('field_a')), '123');
        await tester.pump();

        expect(find.text('Invalid code in Form A'), findsNothing);
        expect(controllerA[codeKey], isNull);
      },
    );

    testWidgets('should call a form with no fields valid', (tester) async {
      final controller = AppFormController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        hostShell(
          AppFormScope(controller: controller, child: const SizedBox()),
        ),
      );

      expect(controller.isValid.value, isTrue);
    });

    testWidgets('should judge every field, and show no error while doing it', (
      tester,
    ) async {
      final controller = AppFormController();
      addTearDown(controller.dispose);
      const titleKey = FormFieldKey(_TestScopeField.title);
      const emailKey = FormFieldKey(_TestScopeField.email);

      await tester.pumpWidget(
        hostShell(
          AppFormScope(
            controller: controller,
            child: Scaffold(
              body: Column(
                children: [
                  AppTextField(
                    fieldKey: titleKey,
                    label: 'Title',
                    validator: (value) =>
                        (value ?? '').isEmpty ? 'Title is required' : null,
                  ),
                  AppTextField(
                    fieldKey: emailKey,
                    label: 'Email',
                    validator: (value) =>
                        (value ?? '').contains('@') ? null : 'Email is invalid',
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Both fields are empty, and neither has been told off for it yet.
      expect(controller.isValid.value, isFalse);
      expect(find.text('Title is required'), findsNothing);
      expect(find.text('Email is invalid'), findsNothing);

      await tester.enterText(
        find.widgetWithText(TextField, 'Title'),
        'A title',
      );
      await tester.pump();

      // One field passing is not the form passing.
      expect(controller.isValid.value, isFalse);

      await tester.enterText(
        find.widgetWithText(TextField, 'Email'),
        'someone@example.com',
      );
      await tester.pump();

      expect(controller.isValid.value, isTrue);

      await tester.enterText(find.widgetWithText(TextField, 'Email'), 'nope');
      await tester.pump();

      expect(controller.isValid.value, isFalse);
    });

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
