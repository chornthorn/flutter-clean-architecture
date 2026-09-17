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
  authorEmail('author_email');

  const _TestCustomField(this.key);

  @override
  final String key;
}

enum _TestSnakeCaseField with SnakeCaseFormFieldKeyMixin implements FormFieldKeyBase {
  isAvailable;
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

      var notificationCount = 0;
      controller.addListener(() => notificationCount++);

      controller.setErrors({'title': 'Error 1', 'body': 'Error 2'});

      expect(controller.errors, {'title': 'Error 1', 'body': 'Error 2'});
      expect(notificationCount, 1);
    });

    test('should clear individual field error and notify', () {
      final controller = AppFormController({'title': 'Error', 'body': 'Body error'});
      addTearDown(controller.dispose);

      var notified = false;
      controller.addListener(() => notified = true);

      controller.clearField(titleKey);

      expect(controller.hasField(titleKey), isFalse);
      expect(controller.hasField(bodyKey), isTrue);
      expect(notified, isTrue);
    });

    test('should not notify when clearing non-existent field', () {
      final controller = AppFormController({'body': 'Body error'});
      addTearDown(controller.dispose);

      var notified = false;
      controller.addListener(() => notified = true);

      controller.clearField(titleKey);

      expect(notified, isFalse);
    });

    test('should clear all errors and notify listeners', () {
      final controller = AppFormController({'title': 'Error 1', 'body': 'Error 2'});
      addTearDown(controller.dispose);

      var notified = false;
      controller.addListener(() => notified = true);

      controller.clear();

      expect(controller.hasErrors, isFalse);
      expect(controller.errors, isEmpty);
      expect(notified, isTrue);
    });

    test('should populate errors from ActionFailure with field errors', () {
      final controller = AppFormController();
      addTearDown(controller.dispose);

      final failure = ActionFailure(
        'Validation failed',
        fieldErrors: {'title': 'Title too short', 'body': 'Body required'},
      );

      controller.bind(failure);

      expect(controller[titleKey], 'Title too short');
      expect(controller[bodyKey], 'Body required');
      expect(controller.hasErrors, isTrue);
    });

    test('should clear errors when ActionSuccess is bound', () {
      final controller = AppFormController({'title': 'Initial error'});
      addTearDown(controller.dispose);

      controller.bind(const ActionSuccess('Success!'));

      expect(controller.hasErrors, isFalse);
      expect(controller.errors, isEmpty);
    });

    test('should look up backend snake_case key for camelCase enum field', () {
      final controller = AppFormController({
        'is_available': 'Must be available',
      });
      addTearDown(controller.dispose);

      const fieldKey = FormFieldKey(_TestField.isAvailable);

      expect(controller[fieldKey], 'Must be available');
      expect(controller.hasField(fieldKey), isTrue);

      controller.clearField(fieldKey);
      expect(controller.hasField(fieldKey), isFalse);
      expect(controller[fieldKey], isNull);
    });

    test('should look up backend camelCase key for snake_case field', () {
      final controller = AppFormController({
        'isAvailable': 'Must be true',
      });
      addTearDown(controller.dispose);

      const fieldKey = FormFieldKey(_TestSnakeCaseField.isAvailable);

      expect(controller[fieldKey], 'Must be true');
      expect(controller.hasField(fieldKey), isTrue);
    });

    test('should respect custom string key on enum implementing FormFieldKeyBase', () {
      final controller = AppFormController({
        'post_title': 'Title required from backend',
        'author_email': 'Email invalid from backend',
      });
      addTearDown(controller.dispose);

      const titleKey = FormFieldKey(_TestCustomField.postTitle);
      const emailKey = FormFieldKey(_TestCustomField.authorEmail);

      expect(controller[titleKey], 'Title required from backend');
      expect(controller[emailKey], 'Email invalid from backend');
      expect(controller.hasField(titleKey), isTrue);
    });

    test('should initialize and read initial values via fromValues', () {
      final controller = AppFormController.fromValues({
        _TestField.title: 'Initial Title',
        _TestField.body: 'Initial Body',
      });
      addTearDown(controller.dispose);

      expect(controller.text(titleKey), 'Initial Title');
      expect(controller.text(bodyKey), 'Initial Body');
      expect(controller.getValue(titleKey), 'Initial Title');
    });

    test('should set and get values dynamically via setValue and setValues', () {
      final controller = AppFormController();
      addTearDown(controller.dispose);

      controller.setValue(titleKey, 'Hello');
      expect(controller.text(titleKey), 'Hello');

      controller.setValues({
        _TestField.title: 'Updated Hello',
        _TestField.body: 'World',
      });
      expect(controller.text(titleKey), 'Updated Hello');
      expect(controller.text(bodyKey), 'World');
    });

    test('should manage and lazily create TextEditingController and Signal per field', () {
      final controller = AppFormController();
      addTearDown(controller.dispose);

      final textCtrl = controller.controller(titleKey, 'Default Val');
      expect(textCtrl.text, 'Default Val');

      final sig = controller.signal(titleKey);
      expect(sig.value, 'Default Val');
    });

    test('should synchronize bidirectional changes between Controller and Signal', () {
      final controller = AppFormController();
      addTearDown(controller.dispose);

      final textCtrl = controller.controller(titleKey);
      final sig = controller.signal(titleKey);

      textCtrl.text = 'From Controller';
      expect(sig.value, 'From Controller');
      expect(controller.text(titleKey), 'From Controller');

      sig.value = 'From Signal';
      expect(textCtrl.text, 'From Signal');
      expect(controller.text(titleKey), 'From Signal');

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

    test('should clear values, errors, and state on clearAll()', () {
      final controller = AppFormController.fromValues({
        _TestField.title: 'Original Title',
      });
      addTearDown(controller.dispose);

      final textCtrl = controller.controller(titleKey);
      controller.setField(titleKey, 'Title error');
      controller.errorMessage.value = 'General error';
      controller.isSubmitting.value = true;

      controller.clearAll();

      expect(textCtrl.text, '');
      expect(controller.text(titleKey), '');
      expect(controller.hasErrors, isFalse);
      expect(controller.errorMessage.value, isNull);
      expect(controller.isSubmitting.value, isFalse);
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
