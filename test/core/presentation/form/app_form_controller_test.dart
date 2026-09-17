import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/core/presentation/action_result.dart';
import 'package:flutter_x/core/presentation/form/app_form_controller.dart';

enum _TestField { title, body }

void main() {
  group('AppFormController', () {
    const titleKey = FormFieldKey(_TestField.title);
    const bodyKey = FormFieldKey(_TestField.body);

    test('should start empty by default', () {
      final controller = AppFormController();

      expect(controller.hasErrors, isFalse);
      expect(controller.errors, isEmpty);
      expect(controller[titleKey], isNull);
      expect(controller.formKey, isNotNull);
      expect(controller.formState, isNull); // not mounted
    });

    test('should populate initial errors', () {
      final controller = AppFormController({'title': 'Too short'});

      expect(controller.hasErrors, isTrue);
      expect(controller[titleKey], 'Too short');
      expect(controller.hasField(titleKey), isTrue);
      expect(controller.hasField(bodyKey), isFalse);
    });

    test('should allow custom formKey via constructor or withKey', () {
      final customKey = GlobalKey<FormState>();
      final controller = AppFormController.withKey(customKey);

      expect(controller.formKey, same(customKey));
    });

    test('should set and update field error and notify', () {
      final controller = AppFormController();
      var notified = false;
      controller.addListener(() => notified = true);

      controller.setField(titleKey, 'Required');

      expect(controller[titleKey], 'Required');
      expect(notified, isTrue);
    });

    test('should set multiple errors at once and notify', () {
      final controller = AppFormController();
      var notified = false;
      controller.addListener(() => notified = true);

      controller.setErrors({'title': 'Required', 'body': 'Too short'});

      expect(controller.errors, {'title': 'Required', 'body': 'Too short'});
      expect(notified, isTrue);
    });

    test('should clear specific field error and notify', () {
      final controller = AppFormController({'title': 'Required'});
      var notified = false;
      controller.addListener(() => notified = true);

      controller.clearField(titleKey);

      expect(controller[titleKey], isNull);
      expect(notified, isTrue);
    });

    test('should not notify when clearing nonexistent field', () {
      final controller = AppFormController({'title': 'Required'});
      var notified = false;
      controller.addListener(() => notified = true);

      controller.clearField(bodyKey);

      expect(notified, isFalse);
    });

    test('should clear all errors on clear and notify', () {
      final controller = AppFormController({'title': 'Required'});
      var notified = false;
      controller.addListener(() => notified = true);

      controller.clear();

      expect(controller.hasErrors, isFalse);
      expect(notified, isTrue);
    });

    test('should populate field errors when binding ActionFailure', () {
      final controller = AppFormController();

      controller.bind(
        const ActionFailure(
          'Validation failed',
          fieldErrors: {'title': 'Required', 'body': 'Too short'},
        ),
      );

      expect(controller.hasErrors, isTrue);
      expect(controller[titleKey], 'Required');
      expect(controller[bodyKey], 'Too short');
    });

    test('should clear errors when binding ActionSuccess', () {
      final controller = AppFormController({'title': 'Required'});

      controller.bind(const ActionSuccess('Saved'));

      expect(controller.hasErrors, isFalse);
      expect(controller[titleKey], isNull);
    });
  });
}
