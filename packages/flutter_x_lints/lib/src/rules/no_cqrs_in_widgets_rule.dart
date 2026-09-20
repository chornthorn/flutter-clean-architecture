import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/error/error.dart';

import '../constants/rule_key.dart';
import '../visitors/no_cqrs_in_widgets_visitor.dart';

/// A library that declares a widget must not import CQRS.
///
/// This is the boundary the app's layering draws: a widget reads state and calls
/// methods on the view model that owns it, and every read and write goes through
/// the view model's dispatcher. A widget that holds a `Query` or a `Command` has
/// taken over a decision that belongs to its view model.
class NoCqrsInWidgetsRule extends AnalysisRule {
  NoCqrsInWidgetsRule()
    : super(
        name: RuleKey.noCqrsInWidgets.value,
        description:
            'Disallows importing the cqrs package from a library that '
            'declares a widget, so dispatch stays in the view model.',
      );

  @override
  LintCode get diagnosticCode => LintCode(
    RuleKey.noCqrsInWidgets.value,
    'A library that declares a widget must not import CQRS.',
    correctionMessage: 'Dispatch from the view model instead, and expose the outcome as state.',
  );

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addImportDirective(this, NoCqrsInWidgetsVisitor(this, context));
  }
}
