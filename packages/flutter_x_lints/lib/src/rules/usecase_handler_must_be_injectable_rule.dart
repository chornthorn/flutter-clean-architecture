import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/error/error.dart';

import '../constants/rule_key.dart';
import '../visitors/usecase_handler_must_be_injectable_visitor.dart';

/// A use case handler must be annotated `@Injectable`.
///
/// A handler is what `cqrs` resolves a command, a query or an event against,
/// and it resolves out of the container — so a handler without the annotation
/// compiles and then fails when the message is dispatched, as a
/// `HandlerNotFoundException` from a screen that looked complete.
///
/// The class is recognised by the contract it implements — `CommandHandler`,
/// `QueryHandler`, `EventHandler`, all resolved to the `cqrs` package — rather
/// than by its name or its folder, so a handler declared anywhere is covered
/// and a class that merely sounds like one is not.
class UsecaseHandlerMustBeInjectableRule extends AnalysisRule {
  UsecaseHandlerMustBeInjectableRule()
    : super(
        name: RuleKey.usecaseHandlerMustBeInjectable.value,
        description:
            'Requires every concrete `CommandHandler`, `QueryHandler` or '
            '`EventHandler` to be annotated `@Injectable`.',
      );

  @override
  LintCode get diagnosticCode => LintCode(
    RuleKey.usecaseHandlerMustBeInjectable.value,
    'A use case handler must be annotated `@Injectable`.',
    correctionMessage:
        'Add `@Injectable(scope: Scope.factory)` above the class, so the '
        'registry can resolve it.',
  );

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addClassDeclaration(
      this,
      UsecaseHandlerMustBeInjectableVisitor(this),
    );
  }
}
