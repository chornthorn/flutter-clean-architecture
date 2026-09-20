import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:flutter_x_lints/src/rules/no_context_watch_in_callback_rule.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(NoContextWatchInCallbackTest);
  });
}

/// The scaffolding the tests share: Flutter's widgets, a `watch` extension on
/// `BuildContext`, and a widget with a `build` that takes one.
///
/// [inBuild] is spliced into that `build`; [build] is appended after it.
String _source({String inBuild = '', String build = ''}) =>
    '''
import 'package:flutter/widgets.dart';

extension WatchX on BuildContext {
  T watch<T>() => Object() as T;
}

class NullWidget extends Widget {
  const NullWidget({Object? onPressed, Object? builder});
}

class MyWidget extends StatelessWidget {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    $inBuild
    return const NullWidget();
  }
}

$build
''';

@reflectiveTest
class NoContextWatchInCallbackTest extends AnalysisRuleTest {
  @override
  bool get addFlutterPackageDep => true;

  @override
  void setUp() {
    rule = NoContextWatchInCallbackRule();
    super.setUp();
  }

  void test_watch_in_an_on_pressed_handler() async {
    final source = _source(
      build: '''
class Button extends MyWidget {
  const Button({super.key});

  void _open(BuildContext context) {
    NullWidget(onPressed: () => context.watch<Object>());
  }
}
''',
    );

    const offending = 'context.watch<Object>()';
    await assertDiagnostics(source, [
      lint(source.indexOf(offending), offending.length),
    ]);
  }

  void test_watch_in_a_block_bodied_handler() async {
    final source = _source(
      build: '''
class Button extends MyWidget {
  const Button({super.key});

  void _open(BuildContext context) {
    NullWidget(
      onPressed: () {
        context.watch<Object>();
      },
    );
  }
}
''',
    );

    const offending = 'context.watch<Object>()';
    await assertDiagnostics(source, [
      lint(source.indexOf(offending), offending.length),
    ]);
  }

  void test_watch_inside_a_nested_callback_in_a_handler() async {
    // The handler is an ancestor, so the reach is still from the handler.
    final source = _source(
      build: '''
class Button extends MyWidget {
  const Button({super.key});

  void _open(BuildContext context) {
    NullWidget(
      onPressed: () {
        [1].forEach((value) => context.watch<Object>());
      },
    );
  }
}
''',
    );

    const offending = 'context.watch<Object>()';
    await assertDiagnostics(source, [
      lint(source.indexOf(offending), offending.length),
    ]);
  }

  void test_watch_in_build() async {
    await assertNoDiagnostics(_source(inBuild: 'context.watch<Object>();'));
  }

  void test_watch_in_a_builder_callback() async {
    // A builder runs during build, so watching there is right.
    await assertNoDiagnostics(
      _source(
        build: '''
class Panel extends MyWidget {
  const Panel({super.key});

  Widget _item(BuildContext context) {
    return NullWidget(builder: () => context.watch<Object>());
  }
}
''',
      ),
    );
  }

  void test_watch_in_a_method_a_handler_calls() async {
    // The handler calls a method; the method is not the handler.
    await assertNoDiagnostics(
      _source(
        build: '''
class Button extends MyWidget {
  const Button({super.key});

  void _open(BuildContext context) {
    NullWidget(onPressed: () => _read(context));
  }

  void _read(BuildContext context) {
    context.watch<Object>();
  }
}
''',
      ),
    );
  }

  void test_a_watch_that_is_not_on_a_build_context() async {
    // A same-named method on something else is not the context extension.
    await assertNoDiagnostics('''
import 'package:flutter/widgets.dart';

class Store {
  T watch<T>() => Object() as T;
}

class List extends StatelessWidget {
  const List({super.key, required this.store});

  final Store store;

  @override
  Widget build(BuildContext context) {
    return NullWidget(onPressed: () => store.watch<Object>());
  }
}

class NullWidget extends Widget {
  const NullWidget({Object? onPressed});
}
''');
  }
}
