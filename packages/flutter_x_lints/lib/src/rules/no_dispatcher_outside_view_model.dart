import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

import '../cqrs.dart';
import '../supertypes.dart';

/// Only a `ViewModel` may dispatch.
///
/// `ViewModel` hands every subclass the app's dispatcher, which makes
/// `dispatcher.command(...)` reachable from anywhere a view model is. This rule
/// keeps it there: a service, a repository or a widget that dispatches has taken
/// the screen's lifecycle out of the screen's hands, and with it the cancellation
/// and the error state the view model owes the route.
class NoDispatcherOutsideViewModel extends AnalysisRule {
  static const LintCode code = LintCode(
    'no_dispatcher_outside_view_model',
    'Only a ViewModel may dispatch.',
    correctionMessage:
        'Move the call into the screen\'s view model and expose it as a method.',
  );

  NoDispatcherOutsideViewModel()
      : super(
          name: 'no_dispatcher_outside_view_model',
          description:
              'Disallows calling CqrsDispatcher.command or .query outside a '
              'ViewModel subclass.',
        );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _Visitor(this, context);
    registry.addMethodInvocation(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // A test drives the dispatcher on purpose; that is the seam being tested.
    if (context.isInTestDirectory) return;

    final element = node.methodName.element;
    if (element is! MethodElement) return;
    if (!_isDispatcherCall(element)) return;

    final owner = enclosingClass(node);
    if (owner != null && hasAnySupertype(owner, const {'ViewModel'})) return;

    rule.reportAtNode(node);
  }
}

/// The dispatcher surface of the `cqrs` package.
///
/// `query` and `command` are declared on `QueryDispatcher` and
/// `CommandDispatcher`, which `CqrsDispatcher` implements, so matching
/// `CqrsDispatcher` alone would never fire against the real package.
const _dispatcherTypes = {
  'CqrsDispatcher',
  'CommandDispatcher',
  'QueryDispatcher',
};

bool _isDispatcherCall(MethodElement element) {
  if (element.name != 'command' && element.name != 'query') return false;

  final owner = element.enclosingElement;
  if (owner is! InterfaceElement) return false;
  if (!isInCqrs(owner)) return false;

  return _dispatcherTypes.contains(owner.name) ||
      owner.allSupertypes.any(
        (type) => _dispatcherTypes.contains(type.element.name),
      );
}
