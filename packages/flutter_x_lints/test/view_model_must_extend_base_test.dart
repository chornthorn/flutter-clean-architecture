import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:flutter_x_lints/src/rules/view_model_must_extend_base_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ViewModelMustExtendBaseTest);
  });
}

/// The base as the app declares it: the lifecycle the route calls on unmount.
const _base = '''
abstract class ViewModel {
  void dispose() {}
}
''';

@reflectiveTest
class ViewModelMustExtendBaseTest extends AnalysisRuleTest {
  /// The directory the rule keys on, under the test package's `lib/`.
  String get _viewModelsDir =>
      '$testPackageLibPath/features/posts/presentation/view_models';

  @override
  void setUp() {
    rule = ViewModelMustExtendBaseRule();
    super.setUp();
  }

  void test_class_in_view_models_without_the_base() async {
    final path = '$_viewModelsDir/post_view_model.dart';
    final source = '''
class PostViewModel {
  const PostViewModel();
}
''';

    newFile(path, source);
    await assertDiagnosticsInFile(path, [
      lint(source.indexOf('PostViewModel'), 'PostViewModel'.length),
    ]);
  }

  void test_class_in_view_models_that_extends_the_base() async {
    final path = '$_viewModelsDir/post_view_model.dart';
    newFile(path, '''
$_base
class PostViewModel extends ViewModel {
  PostViewModel();
}
''');

    await assertDiagnosticsInFile(path, []);
  }

  void test_class_in_view_models_that_implements_the_base() async {
    final path = '$_viewModelsDir/post_view_model.dart';
    newFile(path, '''
$_base
class PostViewModel implements ViewModel {
  @override
  void dispose() {}
}
''');

    await assertDiagnosticsInFile(path, []);
  }

  void test_class_that_extends_another_view_model() async {
    final path = '$_viewModelsDir/posts_home_view_model.dart';
    newFile(path, '''
$_base
class PostsHomeViewModel extends ViewModel {
  PostsHomeViewModel();
}

class PostDetailViewModel extends PostsHomeViewModel {
  PostDetailViewModel();
}
''');

    await assertDiagnosticsInFile(path, []);
  }

  void test_every_class_in_the_file_is_held_to_the_contract() async {
    final path = '$_viewModelsDir/post_view_model.dart';
    final source =
        '''
$_base
class PostViewModel extends ViewModel {
  PostViewModel();
}

class PostDraftViewModel {
  const PostDraftViewModel();
}
''';

    newFile(path, source);
    await assertDiagnosticsInFile(path, [
      lint(source.indexOf('PostDraftViewModel'), 'PostDraftViewModel'.length),
    ]);
  }

  void test_class_outside_view_models() async {
    final path =
        '$testPackageLibPath/features/posts/presentation/post_view_model.dart';
    newFile(path, '''
class PostViewModel {
  const PostViewModel();
}
''');

    await assertDiagnosticsInFile(path, []);
  }

  void test_class_in_a_test_directory() async {
    // A mock declared beside the view model tests is not a view model.
    final path =
        '$testPackageTestPath/features/posts/presentation/view_models/post_view_model_test.dart';
    newFile(path, '''
class MockPostRepository {
  const MockPostRepository();
}
''');

    await assertDiagnosticsInFile(path, []);
  }

  void test_an_enum_in_view_models() async {
    final path = '$_viewModelsDir/post_view_model.dart';
    newFile(path, '''
enum PostSort { newest, oldest }
''');

    await assertDiagnosticsInFile(path, []);
  }
}
