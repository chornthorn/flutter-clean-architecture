import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:flutter_x_lints/src/rules/no_dispatcher_outside_view_model.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(NoDispatcherOutsideViewModelTest);
  });
}

@reflectiveTest
class NoDispatcherOutsideViewModelTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = NoDispatcherOutsideViewModel();
    newPackage('cqrs').addFile('lib/cqrs.dart', '''
class CqrsDispatcher {
  Future<void> query(Object query) async {}
  Future<void> command(Object command) async {}
}
''');
    super.setUp();
  }

  void test_repository_that_dispatches() async {
    final source = '''
import 'package:cqrs/cqrs.dart';

class ViewModel {
  ViewModel(this.dispatcher);

  final CqrsDispatcher dispatcher;
}

class PostRepository {
  PostRepository(this.dispatcher);

  final CqrsDispatcher dispatcher;

  Future<void> load() async => dispatcher.query(0);
}
''';

    const call = 'dispatcher.query(0)';
    await assertDiagnostics(source, [
      lint(source.indexOf(call), call.length),
    ]);
  }

  void test_view_model_that_dispatches() async {
    await assertNoDiagnostics('''
import 'package:cqrs/cqrs.dart';

class ViewModel {
  ViewModel(this.dispatcher);

  final CqrsDispatcher dispatcher;
}

class PostViewModel extends ViewModel {
  PostViewModel(super.dispatcher);

  Future<void> load() async => dispatcher.query(0);
}
''');
  }

  void test_subclass_of_a_view_model_that_dispatches() async {
    await assertNoDiagnostics('''
import 'package:cqrs/cqrs.dart';

class ViewModel {
  ViewModel(this.dispatcher);

  final CqrsDispatcher dispatcher;
}

class PostViewModel extends ViewModel {
  PostViewModel(super.dispatcher);
}

class PostsHomeViewModel extends PostViewModel {
  PostsHomeViewModel(super.dispatcher);

  Future<void> load() async => dispatcher.command(0);
}
''');
  }

  void test_a_look_alike_dispatcher_is_not_the_cqrs_one() async {
    await assertNoDiagnostics('''
class CqrsDispatcher {
  Future<void> query(Object query) async {}
}

class PostRepository {
  PostRepository(this.dispatcher);

  final CqrsDispatcher dispatcher;

  Future<void> load() async => dispatcher.query(0);
}
''');
  }

  void test_a_test_that_dispatches() async {
    final path = '$testPackageTestPath/post_repository_test.dart';
    newFile(path, '''
import 'package:cqrs/cqrs.dart';

class PostRepository {
  PostRepository(this.dispatcher);

  final CqrsDispatcher dispatcher;

  Future<void> load() async => dispatcher.query(0);
}
''');

    await assertDiagnosticsInFile(path, []);
  }
}
