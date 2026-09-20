import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:flutter_x_lints/src/rules/no_get_it_in_ui_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(NoGetItInUiTest);
  });
}

@reflectiveTest
class NoGetItInUiTest extends AnalysisRuleTest {
  @override
  bool get addFlutterPackageDep => true;

  @override
  void setUp() {
    rule = NoGetItInUiRule();
    newPackage('get_it')..addFile('lib/get_it.dart', '''
class GetIt {
  static final GetIt instance = GetIt._();

  GetIt._();

  T get<T extends Object>() => Object() as T;

  T call<T extends Object>() => Object() as T;
}
''');
    // The app's own container, which hands the instance out without the caller
    // ever naming `get_it`.
    newPackage('flutter_x')..addFile('lib/provider.dart', '''
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;
''');
    super.setUp();
  }

  /// Writes [source] at [path] and asserts the rule reports at [code], the
  /// fragment it should point at.
  Future<void> _assertReports(String path, String code, String source) async {
    newFile('$testPackageLibPath/$path', source);
    await assertDiagnosticsInFile('$testPackageLibPath/$path', [
      lint(source.indexOf(code), code.length),
    ]);
  }

  /// Writes [source] at [path] and asserts the rule is silent.
  Future<void> _assertClean(String path, String source) async {
    newFile('$testPackageLibPath/$path', source);
    await assertDiagnosticsInFile('$testPackageLibPath/$path', []);
  }

  void test_widget_that_resolves_through_the_container() async {
    // The reach the import check cannot see: no `get_it` import anywhere.
    const code = 'getIt.get<Object>()';
    await _assertReports(
      'features/posts/presentation/views/posts_home_view.dart',
      code,
      '''
import 'package:flutter/widgets.dart';
import 'package:flutter_x/provider.dart';

class PostsHomeView extends StatelessWidget {
  const PostsHomeView({super.key});

  Object get viewModel => getIt.get<Object>();

  @override
  Widget build(BuildContext context) => const SizedBox();
}
''',
    );
  }

  void test_view_model_that_calls_the_container() async {
    // `getIt<Foo>()` is an implicit `call` on the instance.
    const code = 'getIt<Object>()';
    await _assertReports(
      'features/posts/presentation/view_models/post_view_model.dart',
      code,
      '''
import 'package:flutter_x/provider.dart';

class PostViewModel {
  PostViewModel();

  Object get posts => getIt<Object>();
}
''',
    );
  }

  void
  test_widget_outside_presentation_that_resolves_through_the_container() async {
    const code = 'getIt.get<Object>()';
    await _assertReports(
      'core/design_system/components/app_buttons.dart',
      code,
      '''
import 'package:flutter/widgets.dart';
import 'package:flutter_x/provider.dart';

class AppButton extends StatelessWidget {
  const AppButton({super.key});

  Object get locator => getIt.get<Object>();

  @override
  Widget build(BuildContext context) => const SizedBox();
}
''',
    );
  }

  void test_import_and_call_are_both_reported() async {
    // Importing the package sets the file up to resolve its own dependencies;
    // the call is the reach itself.
    const directive = "import 'package:get_it/get_it.dart';";
    const code = 'GetIt.instance.get<Object>()';
    final path =
        '$testPackageLibPath/features/posts/presentation/views/posts_home_view.dart';
    final source =
        '''
$directive
import 'package:flutter/widgets.dart';

class PostsHomeView extends StatelessWidget {
  const PostsHomeView({super.key});

  Object get viewModel => GetIt.instance.get<Object>();

  @override
  Widget build(BuildContext context) => const SizedBox();
}
''';

    newFile(path, source);
    await assertDiagnosticsInFile(path, [
      lint(source.indexOf(directive), directive.length),
      lint(source.indexOf(code), code.length),
    ]);
  }

  void test_a_get_that_is_not_the_locator() async {
    await _assertClean(
      'features/posts/presentation/views/posts_home_view.dart',
      '''
import 'package:flutter/widgets.dart';

class Settings {
  const Settings();

  Object? get(String key) => null;
}

class PostsHomeView extends StatelessWidget {
  const PostsHomeView({super.key, required this.settings});

  final Settings settings;

  Object? get title => settings.get('title');

  @override
  Widget build(BuildContext context) => const SizedBox();
}
''',
    );
  }

  void test_a_feature_module_file_may_resolve_the_container() async {
    await _assertClean('features/posts/posts_module.dart', '''
import 'package:flutter_x/provider.dart';

final viewModel = getIt.get<Object>();
''');
  }

  void test_a_domain_file_is_out_of_scope() async {
    await _assertClean(
      'features/posts/domain/usecases/get_posts_query.dart',
      '''
import 'package:flutter_x/provider.dart';

class GetPostsQuery {
  const GetPostsQuery();

  Object get locator => getIt.get<Object>();
}
''',
    );
  }

  void test_a_test_file_is_out_of_scope() async {
    final path =
        '$testPackageTestPath/features/posts/presentation/views/posts_home_view_test.dart';
    newFile(path, '''
import 'package:flutter_x/provider.dart';

final viewModel = getIt.get<Object>();
''');

    await assertDiagnosticsInFile(path, []);
  }
}
