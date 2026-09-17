import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/core/presentation/action_result.dart';
import 'package:flutter_x/core/presentation/form/app_form_controller.dart';

void main() {
  group('AppFormController', () {
    test('should start empty by default', () {
      final controller = AppFormController();

      expect(controller.hasErrors, isFalse);
      expect(controller.errors, isEmpty);
      expect(controller['title'], isNull);
      expect(controller.formKey, isNotNull);
      expect(controller.formState, isNull); // not mounted
    });

    test('should populate initial errors', () {
      final controller = AppFormController({'title': 'Too short'});

      expect(controller.hasErrors, isTrue);
      expect(controller['title'], 'Too short');
      expect(controller.hasField('title'), isTrue);
      expect(controller.hasField('body'), isFalse);
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

      controller.setField('title', 'Required');

      expect(controller['title'], 'Required');
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

      controller.clearField('title');

      expect(controller['title'], isNull);
      expect(notified, isTrue);
    });

    test('should not notify when clearing nonexistent field', () {
      final controller = AppFormController({'title': 'Required'});
      var notified = false;
      controller.addListener(() => notified = true);

      controller.clearField('body');

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
      expect(controller['title'], 'Required');
      expect(controller['body'], 'Too short');
    });

    test('should clear errors when binding ActionSuccess', () {
      final controller = AppFormController({'title': 'Required'});

      controller.bind(const ActionSuccess('Saved'));

      expect(controller.hasErrors, isFalse);
      expect(controller['title'], isNull);
    });
  });
}
