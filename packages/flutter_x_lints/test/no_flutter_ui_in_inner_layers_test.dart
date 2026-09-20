import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:flutter_x_lints/src/rules/no_flutter_ui_in_inner_layers_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(NoFlutterUiInInnerLayersTest);
  });
}

@reflectiveTest
class NoFlutterUiInInnerLayersTest extends AnalysisRuleTest {
  @override
  bool get addFlutterPackageDep => true;

  @override
  void setUp() {
    rule = NoFlutterUiInInnerLayersRule();
    super.setUp();
  }

  /// Writes [source] at [path] and asserts the rule reports at [directive].
  Future<void> _assertReports(
    String path,
    String directive,
    String source,
  ) async {
    newFile('$testPackageLibPath/$path', source);
    await assertDiagnosticsInFile('$testPackageLibPath/$path', [
      lint(source.indexOf(directive), directive.length),
    ]);
  }

  Future<void> _assertClean(String path, String source) async {
    newFile('$testPackageLibPath/$path', source);
    await assertDiagnosticsInFile('$testPackageLibPath/$path', []);
  }

  void test_domain_importing_widgets() async {
    const directive = "import 'package:flutter/widgets.dart';";
    await _assertReports(
      'features/posts/domain/entities/post.dart',
      directive,
      '''
$directive

class Post {
  const Post(this.context);

  final BuildContext context;
}
''',
    );
  }

  void test_infrastructure_importing_material() async {
    const directive = "import 'package:flutter/material.dart';";
    await _assertReports(
      'features/posts/infrastructure/repositories/remote_post_repository.dart',
      directive,
      '''
$directive

class RemotePostRepository {
  const RemotePostRepository(this.scaffold);

  final Scaffold scaffold;
}
''',
    );
  }

  void test_domain_exporting_widgets() async {
    const directive = "export 'package:flutter/widgets.dart';";
    await _assertReports(
      'features/posts/domain/posts_domain.dart',
      directive,
      '$directive\n',
    );
  }

  void test_presentation_importing_widgets_is_fine() async {
    // Presentation is where the widgets live.
    await _assertClean(
      'features/posts/presentation/views/posts_home_view.dart',
      '''
import 'package:flutter/widgets.dart';

class PostsHomeView extends StatelessWidget {
  const PostsHomeView({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox();
}
''',
    );
  }

  void test_a_core_file_is_outside_the_layering() async {
    await _assertClean('core/design_system/components/app_card.dart', '''
import 'package:flutter/widgets.dart';

class AppCard extends StatelessWidget {
  const AppCard({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox();
}
''');
  }

  void test_a_feature_module_file_is_outside_the_layering() async {
    await _assertClean('features/posts/posts_module.dart', '''
import 'package:flutter/widgets.dart';

class PostsShell extends StatelessWidget {
  const PostsShell({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox();
}
''');
  }

  void test_domain_importing_something_that_is_not_ui() async {
    await _assertClean(
      'features/posts/domain/usecases/get_posts_query.dart',
      '''
import 'dart:async';

class GetPostsQuery {
  const GetPostsQuery(this.settled);

  final Future<void> settled;
}
''',
    );
  }
}
