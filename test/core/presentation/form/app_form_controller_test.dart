import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_x/core/presentation/action_result.dart';
import 'package:flutter_x/core/presentation/form/app_form_controller.dart';

enum _TestField implements FormFieldKeyBase {
  title,
  body,
  email,
  isAvailable;

  @override
  String get key => name;
}

enum _TestCustomField implements FormFieldKeyBase {
  postTitle('post_title'),
  authorEmail('author_email'),
  isAvailable('is_available'),
  body('body');

  const _TestCustomField(this.key);

  @override
  final String key;
}

enum _TestSnakeCaseField with SnakeCaseFormFieldKeyMixin implements FormFieldKeyBase {
  isAvailable,
  productCount;
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('AppFormController', () {
    const titleKey = FormFieldKey(_TestField.title);
    const bodyKey = FormFieldKey(_TestField.body);
    const emailKey = FormFieldKey(_TestField.email);

    test('should start empty when no initial errors provided', () {
      final controller = AppFormController();
      addTearDown(controller.dispose);

      expect(controller.hasErrors, isFalse);
      expect(controller.errors, isEmpty);
      expect(controller[titleKey], isNull);
    });

    test('should populate initial errors if provided', () {
      final controller = AppFormController({'title': 'Required'});
      addTearDown(controller.dispose);

      expect(controller.hasErrors, isTrue);
      expect(controller[titleKey], 'Required');
      expect(controller[bodyKey], isNull);
    });

    test('should report error via operator []', () {
      final controller = AppFormController({'title': 'Title error'});
      addTearDown(controller.dispose);

      expect(controller[titleKey], 'Title error');
      expect(controller[emailKey], isNull);
    });

    test('should report hasErrors correctly', () {
      final emptyController = AppFormController();
      addTearDown(emptyController.dispose);
      expect(emptyController.hasErrors, isFalse);

      final errorController = AppFormController({'email': 'Invalid'});
      addTearDown(errorController.dispose);
      expect(errorController.hasErrors, isTrue);
    });

    test('should report hasField correctly', () {
      final controller = AppFormController({'title': 'Error'});
      addTearDown(controller.dispose);

      expect(controller.hasField(titleKey), isTrue);
      expect(controller.hasField(bodyKey), isFalse);
    });

    test('should set individual field error and notify', () {
      final controller = AppFormController();
      addTearDown(controller.dispose);
      var notified = false;
      controller.addListener(() => notified = true);

      controller.setField(titleKey, 'Invalid title');

      expect(controller[titleKey], 'Invalid title');
      expect(notified, isTrue);
    });

    test('should update errors and notify listeners', () {
      final controller = AppFormController();
      addTearDown(controller.dispose);
      var notified = false;
      controller.addListener(() => notified = true);

      controller.setErrors({'title': 'Required', 'body': 'Too short'});

      expect(controller.errors, {'title': 'Required', 'body': 'Too short'});
      expect(notified, isTrue);
    });

    test('should clear specific field error and notify', () {
      final controller = AppFormController({'title': 'Required'});
      addTearDown(controller.dispose);
      var notified = false;
      controller.addListener(() => notified = true);

      controller.clearField(titleKey);

      expect(controller[titleKey], isNull);
      expect(notified, isTrue);
    });

    test('should not notify when clearing nonexistent field', () {
      final controller = AppFormController({'title': 'Required'});
      addTearDown(controller.dispose);
      var notified = false;
      controller.addListener(() => notified = true);

      controller.clearField(bodyKey);

      expect(notified, isFalse);
    });

    test('should clear all errors on clear and notify', () {
      final controller = AppFormController({'title': 'Required'});
      addTearDown(controller.dispose);
      var notified = false;
      controller.addListener(() => notified = true);

      controller.clear();

      expect(controller.hasErrors, isFalse);
      expect(notified, isTrue);
    });

    test('should populate field errors when binding ActionFailure', () {
      final controller = AppFormController();
      addTearDown(controller.dispose);

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
      addTearDown(controller.dispose);

      controller.bind(const ActionSuccess('Saved'));

      expect(controller.hasErrors, isFalse);
      expect(controller[titleKey], isNull);
    });

    test('should support custom string wire keys from backend differences', () {
      final controller = AppFormController();
      addTearDown(controller.dispose);
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
      addTearDown(controller.dispose);
      const availableKey = FormFieldKey(_TestField.isAvailable);

      expect(availableKey.key, 'isAvailable');
      expect(availableKey.snakeCase, 'is_available');

      controller.bind(
        const ActionFailure(
          'Validation failed',
          fieldErrors: {'is_available': 'Cannot be false'},
        ),
      );

      expect(controller[availableKey], 'Cannot be false');
      expect(controller.hasField(availableKey), isTrue);

      controller.clearField(availableKey);
      expect(controller[availableKey], isNull);
      expect(controller.hasField(availableKey), isFalse);
    });

    test('should support SnakeCaseFormFieldKeyMixin to automatically emit snake_case keys', () {
      const snakeField = FormFieldKey(_TestSnakeCaseField.isAvailable);
      const countField = FormFieldKey(_TestSnakeCaseField.productCount);

      expect(snakeField.key, 'is_available');
      expect(countField.key, 'product_count');
    });

    test('should manage TextEditingControllers and pre-fill initial values', () {
      final controller = AppFormController.fromValues({
        _TestField.title: 'My Initial Title',
      });
      addTearDown(controller.dispose);

      expect(controller.text(titleKey), 'My Initial Title');
      expect(controller.getValue(titleKey), 'My Initial Title');

      final textCtrl = controller.controller(titleKey);
      expect(textCtrl.text, 'My Initial Title');

      // Reusing controller returns identical instance
      expect(controller.controller(titleKey), same(textCtrl));
    });

    test('should synchronize Signal and TextEditingController bidirectionally', () {
      final controller = AppFormController();
      addTearDown(controller.dispose);

      final textCtrl = controller.controller(titleKey);
      final sig = controller.signal(titleKey);

      // 1. Controller -> Signal
      textCtrl.text = 'From Controller';
      expect(sig.value, 'From Controller');
      expect(controller.text(titleKey), 'From Controller');

      // 2. Signal -> Controller
      sig.value = 'From Signal';
      expect(textCtrl.text, 'From Signal');
      expect(controller.text(titleKey), 'From Signal');

      // 3. setValue -> updates both
      controller.setValue(titleKey, 'Updated Programmatically');
      expect(textCtrl.text, 'Updated Programmatically');
      expect(sig.value, 'Updated Programmatically');
    });

    test('should auto-clear field error when typing in managed controller', () {
      final controller = AppFormController();
      addTearDown(controller.dispose);

      controller.setField(titleKey, 'Title error');
      expect(controller.hasField(titleKey), isTrue);

      final textCtrl = controller.controller(titleKey);
      textCtrl.text = 'New input';

      expect(controller.hasField(titleKey), isFalse);
      expect(controller[titleKey], isNull);
    });

    test('should reset managed controllers to initial values on reset()', () {
      final controller = AppFormController.fromValues({
        _TestField.title: 'Original Title',
      });
      addTearDown(controller.dispose);

      final textCtrl = controller.controller(titleKey);
      textCtrl.text = 'Modified Title';
      controller.setField(titleKey, 'Some error');

      expect(controller.text(titleKey), 'Modified Title');
      expect(controller.hasField(titleKey), isTrue);

      controller.reset();

      expect(textCtrl.text, 'Original Title');
      expect(controller.text(titleKey), 'Original Title');
      expect(controller.hasField(titleKey), isFalse);
    });

    test('should clear values on clearValues()', () {
      final controller = AppFormController.fromValues({
        _TestField.title: 'Original Title',
      });
      addTearDown(controller.dispose);

      final textCtrl = controller.controller(titleKey);
      expect(textCtrl.text, 'Original Title');

      controller.clearValues();

      expect(textCtrl.text, '');
      expect(controller.text(titleKey), '');
    });

    test('should support RawFormFieldKey and FormFieldKey.raw', () {
      final rawKey = FormFieldKey.raw('custom_input');
      expect(rawKey.key, 'custom_input');

      final controller = AppFormController.fromValues({
        'custom_input': 'Dynamic value',
      });
      addTearDown(controller.dispose);

      expect(controller.text(rawKey), 'Dynamic value');
    });

    test('should set errorMessage when binding ActionFailure with no field errors', () {
      final controller = AppFormController();
      addTearDown(controller.dispose);

      controller.bind(const ActionFailure('Something went wrong'));
      expect(controller.errorMessage.value, 'Something went wrong');
      expect(controller.hasErrors, isFalse);
    });

    test('should keep errorMessage null when binding ActionFailure with field errors', () {
      final controller = AppFormController();
      addTearDown(controller.dispose);

      controller.bind(
        const ActionFailure(
          'Validation failed',
          fieldErrors: {'title': 'Required'},
        ),
      );
      expect(controller.errorMessage.value, isNull);
      expect(controller.hasErrors, isTrue);
    });

    test('should clear errorMessage on clear() or bind(ActionSuccess)', () {
      final controller = AppFormController();
      addTearDown(controller.dispose);

      controller.bind(const ActionFailure('Error'));
      expect(controller.errorMessage.value, 'Error');

      controller.clear();
      expect(controller.errorMessage.value, isNull);

      controller.bind(const ActionFailure('Another error'));
      expect(controller.errorMessage.value, 'Another error');

      controller.bind(const ActionSuccess('Success'));
      expect(controller.errorMessage.value, isNull);
    });

    test('should track isSubmitting during submit()', () async {
      final controller = AppFormController();
      addTearDown(controller.dispose);

      expect(controller.isSubmitting.value, isFalse);

      bool wasSubmittingDuringAction = false;
      final result = await controller.submit(() async {
        wasSubmittingDuringAction = controller.isSubmitting.value;
        return const ActionSuccess('Done');
      });

      expect(wasSubmittingDuringAction, isTrue);
      expect(controller.isSubmitting.value, isFalse);
      expect(result, isA<ActionSuccess>());
    });
  });
}
