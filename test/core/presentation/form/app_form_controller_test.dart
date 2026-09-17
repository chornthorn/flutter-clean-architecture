import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/core/presentation/action_result.dart';
import 'package:flutter_x/core/presentation/form/app_form_controller.dart';

enum _TestField with FormFieldKeyMixin { title, body, isAvailable }

enum _TestSnakeCaseField with SnakeCaseFormFieldKeyMixin { isAvailable, productCount }

enum _TestCustomField implements FormFieldKeyBase {
  postTitle('post_title'),
  authorEmail('author_email'),
  isAvailable('is_available'),
  body;

  const _TestCustomField([this.customKey]);
  final String? customKey;

  @override
  String get key => customKey ?? name;
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  group('AppFormController', () {
    const titleKey = FormFieldKey(_TestField.title);
    const bodyKey = FormFieldKey(_TestField.body);
    const isAvailableKey = FormFieldKey(_TestField.isAvailable);

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

    test('should support custom string wire keys from backend differences', () {
      final controller = AppFormController();
      const customTitle = FormFieldKey(_TestCustomField.postTitle);
      const customEmail = FormFieldKey(_TestCustomField.authorEmail);
      const customAvailable = FormFieldKey(_TestCustomField.isAvailable);
      const defaultBody = FormFieldKey(_TestCustomField.body);

      expect(customTitle.key, 'post_title');
      expect(customEmail.key, 'author_email');
      expect(customAvailable.key, 'is_available');
      expect(defaultBody.key, 'body');

      controller.bind(
        const ActionFailure(
          'Validation failed',
          fieldErrors: {
            'post_title': 'Title is invalid',
            'author_email': 'Email format wrong',
            'is_available': 'Must be true or false',
            'body': 'Body is required',
          },
        ),
      );

      expect(controller[customTitle], 'Title is invalid');
      expect(controller[customEmail], 'Email format wrong');
      expect(controller[customAvailable], 'Must be true or false');
      expect(controller[defaultBody], 'Body is required');
    });

    test('should automatically match server snake_case is_available when enum is camelCase isAvailable', () {
      final controller = AppFormController();

      // Enum is camelCase: _TestField.isAvailable
      expect(isAvailableKey.key, 'isAvailable');
      expect(isAvailableKey.snakeCase, 'is_available');

      // Server returns snake_case error: 'is_available'
      controller.bind(
        const ActionFailure(
          'Validation failed',
          fieldErrors: {'is_available': 'Item is currently unavailable.'},
        ),
      );

      // Successfully matches via snakeCase fallback!
      expect(controller.hasField(isAvailableKey), isTrue);
      expect(controller[isAvailableKey], 'Item is currently unavailable.');

      // Clearing field clears 'is_available' from errors
      controller.clearField(isAvailableKey);
      expect(controller.hasField(isAvailableKey), isFalse);
      expect(controller[isAvailableKey], isNull);
    });

    test('should support SnakeCaseFormFieldKeyMixin to automatically emit snake_case keys', () {
      const snakeField = FormFieldKey(_TestSnakeCaseField.isAvailable);
      const countField = FormFieldKey(_TestSnakeCaseField.productCount);

      expect(snakeField.key, 'is_available');
      expect(countField.key, 'product_count');
    });
  });
}
