import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:flutter_x_lints/src/rules/view_model_writable_signals_must_be_private_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ViewModelWritableSignalsMustBePrivateTest);
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
class ViewModelWritableSignalsMustBePrivateTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = ViewModelWritableSignalsMustBePrivateRule();
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

  void test_inferred_writable_signal_field() async {
    // The app's shape: no annotation at all, the type comes from the call.
    final source =
        '''
$_prelude
class PostViewModel extends ViewModel {
  final posts = AsyncSignal<List<String>>();

  ReadonlySignal<AsyncState<List<String>>> get posts2 => posts;
}
''';

    const offending = 'posts = AsyncSignal';
    await assertDiagnostics(source, [
      lint(source.indexOf(offending), 'posts'.length),
    ]);
  }

  void test_annotated_writable_signal_field() async {
    final source =
        '''
$_prelude
class PostViewModel extends ViewModel {
  final AsyncSignal<List<String>> posts = AsyncSignal<List<String>>();
}
''';

    const offending = 'posts = AsyncSignal';
    await assertDiagnostics(source, [
      lint(source.indexOf(offending), 'posts'.length),
    ]);
  }

  void test_public_computed_field() async {
    // Read-only: it cannot be written through, so there is nothing to hide.
    await assertNoDiagnostics('''
$_prelude
class PostViewModel extends ViewModel {
  final _count = Signal<int>();

  late final total = Computed<int>();
}
''');
  }

  void test_public_read_only_signal_field() async {
    await assertNoDiagnostics('''
$_prelude
class PostViewModel extends ViewModel {
  final _posts = AsyncSignal<List<String>>();

  late final ReadonlySignal<AsyncState<List<String>>> posts = _posts;
}
''');
  }

  void test_public_plain_signal_field() async {
    final source =
        '''
$_prelude
class PostViewModel extends ViewModel {
  final count = Signal<int>();
}
''';

    const offending = 'count = Signal';
    await assertDiagnostics(source, [
      lint(source.indexOf(offending), 'count'.length),
    ]);
  }

  void test_private_signal_fields() async {
    await assertNoDiagnostics('''
$_prelude
class PostViewModel extends ViewModel {
  final _posts = AsyncSignal<List<String>>();
  final _count = Signal<int>();
  late final _total = Computed<int>();

  ReadonlySignal<AsyncState<List<String>>> get posts => _posts;
}
''');
  }

  void test_public_field_that_is_not_a_signal() async {
    await assertNoDiagnostics('''
abstract class ViewModel {
  ViewModel();
}

class PostViewModel extends ViewModel {
  final items = <String>[];

  static const authorId = 1;
}
''');
  }

  void test_a_class_that_is_not_a_view_model() async {
    await assertNoDiagnostics('''
$_prelude
class PostStore {
  final posts = AsyncSignal<List<String>>();
}
''');
  }

  void test_a_local_variable_is_not_a_field() async {
    // A local never reaches a view.
    await assertNoDiagnostics('''
$_prelude
class PostViewModel extends ViewModel {
  AsyncSignal<List<String>> make() {
    final posts = AsyncSignal<List<String>>();
    return posts;
  }
}
''');
  }
}
