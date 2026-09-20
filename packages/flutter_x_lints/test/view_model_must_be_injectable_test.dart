import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:flutter_x_lints/src/rules/view_model_must_be_injectable_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ViewModelMustBeInjectableTest);
  });
}

/// The base the app's view models extend.
const _viewModelBase = '''
abstract class ViewModel {
  ViewModel();
}
''';

/// The same, with the container's annotation in scope.
const _withInjectify = '''
import 'package:injectify/injectify.dart';

$_viewModelBase''';

@reflectiveTest
class ViewModelMustBeInjectableTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = ViewModelMustBeInjectableRule();
    newPackage('injectify')..addFile('lib/injectify.dart', '''
class Scope {
  static const factory = Scope();
  static const lazySingleton = Scope();
}

class Injectable {
  const Injectable({this.scope, this.as});

  final Scope? scope;
  final Object? as;
}
''');
    // A same-named annotation from elsewhere, for the look-alike test.
    newPackage('not_injectify')..addFile('lib/not_injectify.dart', '''
class Injectable {
  const Injectable();
}
''');
    super.setUp();
  }

  void test_view_model_without_the_annotation() async {
    final source =
        '''
$_viewModelBase
class PostViewModel extends ViewModel {
  PostViewModel();
}
''';

    await assertDiagnostics(source, [
      lint(source.indexOf('PostViewModel'), 'PostViewModel'.length),
    ]);
  }

  void test_view_model_with_the_annotation() async {
    await assertNoDiagnostics('''
$_withInjectify
@Injectable(scope: Scope.factory)
class PostViewModel extends ViewModel {
  PostViewModel();
}
''');
  }

  void test_annotation_without_arguments() async {
    await assertNoDiagnostics('''
$_withInjectify
@Injectable()
class PostViewModel extends ViewModel {
  PostViewModel();
}
''');
  }

  void test_annotation_above_another_annotation() async {
    await assertNoDiagnostics('''
$_withInjectify
@Deprecated('later')
@Injectable(scope: Scope.factory)
class PostViewModel extends ViewModel {
  PostViewModel();
}
''');
  }

  void test_a_class_that_is_not_a_view_model() async {
    await assertNoDiagnostics('''
$_viewModelBase
class PostRepository {
  PostRepository();
}
''');
  }

  void test_an_abstract_base_view_model() async {
    // The container builds the subclasses, not the base.
    await assertNoDiagnostics('''
$_viewModelBase
abstract class PostsListViewModel extends ViewModel {
  PostsListViewModel();
}
''');
  }

  void test_the_base_class_itself() async {
    await assertNoDiagnostics(_viewModelBase);
  }

  void test_a_look_alike_annotation_is_not_the_container_one() async {
    // The annotation resolves to another package's class, which registers
    // nothing, so the view model still cannot be built.
    final source =
        '''
import 'package:not_injectify/not_injectify.dart';

$_viewModelBase
@Injectable()
class PostViewModel extends ViewModel {
  PostViewModel();
}
''';

    await assertDiagnostics(source, [
      lint(source.indexOf('PostViewModel'), 'PostViewModel'.length),
    ]);
  }
}
