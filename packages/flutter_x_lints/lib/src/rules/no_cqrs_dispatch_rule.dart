import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/error/error.dart';

import '../constants/rule_key.dart';
import '../visitors/no_cqrs_dispatch_visitor.dart';

/// A feature reaches the domain through a use case, not by dispatching.
///
/// A read or a write is a use case the view model was built with. Dispatching
/// one instead hands the decision to whoever holds the dispatcher, and with it
/// the cancellation and the error state the view model owes the route.
///
/// The dispatcher keeps exactly one call: `publish`, the module-to-module
/// message. That one belongs to a use case in `domain/usecases/`, where the
/// module that raises the event is the module that owns it.
class NoCqrsDispatchRule extends AnalysisRule {
  NoCqrsDispatchRule()
    : super(
        name: RuleKey.noCqrsDispatch.value,
        description:
            'Disallows calling CqrsDispatcher.command or .query, and '
            'disallows .publish outside a `usecases/` directory.',
      );

  @override
  LintCode get diagnosticCode => LintCode(
    RuleKey.noCqrsDispatch.value,
    'A feature reaches the domain through a use case, not by dispatching.',
    correctionMessage:
        'Give the view model the use case it needs instead, or move the '
        'publish into `domain/usecases/`.',
  );

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addMethodInvocation(
      this,
      NoCqrsDispatchVisitor(this, context),
    );
  }
}
