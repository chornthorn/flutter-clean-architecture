import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/error/error.dart';

import '../constants/rule_key.dart';
import '../visitors/no_dispatcher_outside_view_model_visitor.dart';

/// Only a `ViewModel` may dispatch.
///
/// `ViewModel` hands every subclass the app's dispatcher, which makes
/// `dispatcher.command(...)` reachable from anywhere a view model is. This rule
/// keeps it there: a service, a repository or a widget that dispatches has taken
/// the screen's lifecycle out of the screen's hands, and with it the cancellation
/// and the error state the view model owes the route.
class NoDispatcherOutsideViewModelRule extends AnalysisRule {
  NoDispatcherOutsideViewModelRule()
    : super(
        name: RuleKey.noDispatcherOutsideViewModel.value,
        description:
            'Disallows calling CqrsDispatcher.command or .query outside a '
            'ViewModel subclass.',
      );

  @override
  LintCode get diagnosticCode => LintCode(
    RuleKey.noDispatcherOutsideViewModel.value,
    'Only a ViewModel may dispatch.',
    correctionMessage: 'Move the call into the screen\'s view model and expose it as a method.',
  );

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addMethodInvocation(
      this,
      NoDispatcherOutsideViewModelVisitor(this, context),
    );
  }
}
