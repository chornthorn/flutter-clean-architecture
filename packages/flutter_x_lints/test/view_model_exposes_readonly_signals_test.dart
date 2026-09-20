import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:flutter_x_lints/src/rules/view_model_exposes_readonly_signals_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ViewModelExposesReadonlySignalsTest);
  });
}

/// What every test source opens with: the signals package, and the base the
/// app's view models extend.
const _prelude = '''
import 'package:signals_core/signals_core.dart';

abstract class ViewModel {
  ViewModel();
}
''';

@reflectiveTest
class ViewModelExposesReadonlySignalsTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = ViewModelExposesReadonlySignalsRule();
    // Mirrors the real hierarchy: the writable and read-only signals come from
    // `preact_signals`, and `AsyncSignal` extends the writable one.
    newPackage('preact_signals')..addFile('lib/preact_signals.dart', '''
abstract class ReadonlySignal<T> {
  T get value;
}

class Signal<T> extends ReadonlySignal<T> {
  @override
  T value = Object() as T;
}

class Computed<T> extends ReadonlySignal<T> {
  @override
  T value = Object() as T;
}
''');
    newPackage('signals_core')..addFile('lib/signals_core.dart', '''
import 'package:preact_signals/preact_signals.dart';

export 'package:preact_signals/preact_signals.dart';

class AsyncState<T> {
  const AsyncState();
}

class AsyncSignal<T> extends Signal<AsyncState<T>> {
  @override
  AsyncState<T> value = AsyncState<T>();
}
''');
    super.setUp();
  }

  void test_async_signal_getter_typed_as_async_signal() async {
    final source =
        '''
$_prelude
class PostViewModel extends ViewModel {
  final _posts = AsyncSignal<List<String>>();

  AsyncSignal<List<String>> get posts => _posts;
}
''';

    const offending = 'AsyncSignal<List<String>>';
    await assertDiagnostics(source, [
      // The last occurrence: the getter's return type, not the field's.
      lint(source.lastIndexOf(offending), offending.length),
    ]);
  }

  void test_async_signal_getter_typed_as_the_read_only_base() async {
    await assertNoDiagnostics('''
$_prelude
class PostViewModel extends ViewModel {
  final _posts = AsyncSignal<List<String>>();

  ReadonlySignal<AsyncState<List<String>>> get posts => _posts;
}
''');
  }

  void test_plain_signal_getter_typed_as_signal() async {
    final source =
        '''
$_prelude
class PostViewModel extends ViewModel {
  final _count = Signal<int>();

  Signal<int> get count => _count;
}
''';

    const offending = 'Signal<int> get count';
    await assertDiagnostics(source, [
      lint(source.indexOf(offending), 'Signal<int>'.length),
    ]);
  }

  void test_computed_getter() async {
    await assertNoDiagnostics('''
$_prelude
class PostViewModel extends ViewModel {
  Computed<int> get doubled => Computed<int>();
}
''');
  }

  void test_private_getter_of_a_writable_signal() async {
    // A private getter is the view model's own business.
    await assertNoDiagnostics('''
$_prelude
class PostViewModel extends ViewModel {
  final _posts = AsyncSignal<List<String>>();

  AsyncSignal<List<String>> get _postsOnScreen => _posts;
}
''');
  }

  void test_getter_of_something_that_is_not_a_signal() async {
    await assertNoDiagnostics('''
abstract class ViewModel {
  ViewModel();
}

class PostViewModel extends ViewModel {
  final _items = <String>[];

  List<String> get items => _items;
}
''');
  }

  void test_a_class_that_is_not_a_view_model() async {
    // Nothing is exposed to a view, so nothing is leaked to one.
    await assertNoDiagnostics('''
$_prelude
class PostStore {
  final _posts = AsyncSignal<List<String>>();

  AsyncSignal<List<String>> get posts => _posts;
}
''');
  }

  void test_a_subclass_of_a_view_model() async {
    final source =
        '''
$_prelude
class PostsHomeViewModel extends ViewModel {
  PostsHomeViewModel();
}

class PostDetailViewModel extends PostsHomeViewModel {
  final _post = AsyncSignal<String>();

  AsyncSignal<String> get post => _post;
}
''';

    const offending = 'AsyncSignal<String>';
    await assertDiagnostics(source, [
      // The last occurrence: the getter's return type, not the field's.
      lint(source.lastIndexOf(offending), offending.length),
    ]);
  }
}
