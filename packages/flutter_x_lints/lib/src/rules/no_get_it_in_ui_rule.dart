import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/error/error.dart';

import '../constants/rule_key.dart';
import '../visitors/no_get_it_in_ui_visitor.dart';

/// A widget or a UI file must not reach for the service locator.
///
/// `getIt<PostViewModel>()` resolves at the moment it runs, so nothing in a
/// widget's signature says what it needs: the dependency is invisible to a
/// reader, to the compiler, and to a test that wants to hand in a double. The
/// router's provider already builds a screen's view model and passes it down,
/// and that is the one place the container is meant to be read.
///
/// Both the import and the call are reported. Importing `get_it` sets a UI file
/// up to resolve its own dependencies, and calling through a `GetIt` instance is
/// the reach itself — which the app's own `provider.dart` allows without a
/// `get_it` import in sight.
///
/// A widget is recognised by what it declares, so the rule holds wherever one
/// lives — including a design-system component under `core/`, which no folder
/// rule would reach. A UI file that declares no widget is recognised by its
/// `presentation/` directory.
class NoGetItInUiRule extends AnalysisRule {
  NoGetItInUiRule()
    : super(
        name: RuleKey.noGetItInUi.value,
        description:
            'Disallows reaching for a get_it container from a library that '
            'declares a widget, or from a file under a `presentation/` '
            'directory: both importing the package and calling through a '
            '`GetIt` instance.',
      );

  @override
  LintCode get diagnosticCode => LintCode(
    RuleKey.noGetItInUi.value,
    'A widget or UI file must not reach for the service locator.',
    correctionMessage:
        'Take the dependency as a parameter instead: the router\'s provider '
        'builds the view model and passes it down.',
  );

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    // A test wires the container itself on purpose; that is the seam being
    // tested, and `test/` mirrors the feature layout.
    if (context.isInTestDirectory) return;

    final visitor = NoGetItInUiVisitor(this, context);
    registry.addImportDirective(this, visitor);
    registry.addMethodInvocation(this, visitor);
    registry.addFunctionExpressionInvocation(this, visitor);
  }
}
