import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';

import '../utils/cqrs.dart';
import '../utils/supertypes.dart';

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

/// Reports a dispatch that happens outside a view model.
class NoDispatcherOutsideViewModelVisitor extends SimpleAstVisitor<void> {
  NoDispatcherOutsideViewModelVisitor(this.rule, this.context);

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
