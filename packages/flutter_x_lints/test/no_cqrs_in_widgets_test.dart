import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:flutter_x_lints/src/rules/no_cqrs_in_widgets.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(NoCqrsInWidgetsTest);
  });
}

@reflectiveTest
class NoCqrsInWidgetsTest extends AnalysisRuleTest {
  @override
  bool get addFlutterPackageDep => true;

  @override
  void setUp() {
    rule = NoCqrsInWidgets();
    newPackage('cqrs').addFile('lib/cqrs.dart', '''
class CqrsDispatcher {
  Future<void> query(Object query) async {}
  Future<void> command(Object command) async {}
}
''');
    super.setUp();
  }

  void test_widget_that_holds_a_dispatcher() async {
    final source = '''
import 'package:cqrs/cqrs.dart';
import 'package:flutter/widgets.dart';

class PostTile extends StatelessWidget {
  const PostTile({super.key, required this.dispatcher});

  final CqrsDispatcher dispatcher;
}
''';

    const directive = "import 'package:cqrs/cqrs.dart';";
    await assertDiagnostics(source, [
      lint(source.indexOf(directive), directive.length),
    ]);
  }

  void test_state_class_that_holds_a_dispatcher() async {
    final source = '''
import 'package:cqrs/cqrs.dart';
import 'package:flutter/widgets.dart';

class PostTile extends StatefulWidget {
  const PostTile({super.key, required this.dispatcher});

  final CqrsDispatcher dispatcher;

  @override
  State<PostTile> createState() => _PostTileState();
}

class _PostTileState extends State<PostTile> {
  @override
  Widget build(BuildContext context) => const SizedBox();
}
''';

    const directive = "import 'package:cqrs/cqrs.dart';";
    await assertDiagnostics(source, [
      lint(source.indexOf(directive), directive.length),
    ]);
  }

  void test_view_model_that_holds_a_dispatcher() async {
    await assertNoDiagnostics('''
import 'package:cqrs/cqrs.dart';

class PostViewModel {
  const PostViewModel(this.dispatcher);

  final CqrsDispatcher dispatcher;
}
''');
  }

  void test_widget_that_does_not_import_cqrs() async {
    await assertNoDiagnostics('''
import 'package:flutter/widgets.dart';

class PostTile extends StatelessWidget {
  const PostTile({super.key});
}
''');
  }
}
