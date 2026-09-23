import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/error/error.dart';

import '../constants/rule_key.dart';
import '../visitors/usecase_must_be_injectable_visitor.dart';

/// A use case must be annotated `@Injectable`.
///
/// The container builds a screen's use cases and hands them to its view model;
/// a `cqrs` handler it resolves out of that same container. A use case without
/// the annotation compiles and then fails when the screen is opened — or, for a
/// handler, as a `HandlerNotFoundException` from a screen that looked complete.
///
/// Two shapes count, and neither is recognised by its name. A class implementing
/// `CommandHandler`, `QueryHandler` or `EventHandler` is a handler, resolved to
/// the `cqrs` package so a look-alike is not mistaken for one. A class declared
/// under a `usecases/` directory is a use case by where it lives, unless it
/// extends one of `cqrs`'s message contracts — a message is data the handler
/// takes, not something the container builds.
class UsecaseMustBeInjectableRule extends AnalysisRule {
  UsecaseMustBeInjectableRule()
    : super(
        name: RuleKey.usecaseMustBeInjectable.value,
        description:
            'Requires every concrete `CommandHandler`, `QueryHandler` or '
            '`EventHandler`, and every use case declared under `usecases/`, '
            'to be annotated `@Injectable`.',
      );

  @override
  LintCode get diagnosticCode => LintCode(
    RuleKey.usecaseMustBeInjectable.value,
    'A use case must be annotated `@Injectable`.',
    correctionMessage:
        'Add `@Injectable(scope: Scope.factory)` above the class, so the '
        'container can build it.',
  );

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addClassDeclaration(
      this,
      UsecaseMustBeInjectableVisitor(this, context),
    );
  }
}
