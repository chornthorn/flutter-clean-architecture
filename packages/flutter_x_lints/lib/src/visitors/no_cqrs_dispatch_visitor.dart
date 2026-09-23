import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';

import '../utils/cqrs.dart';
import '../utils/paths.dart';

/// The dispatcher surface of the `cqrs` package.
///
/// `command`, `query` and `publish` are declared on `CommandDispatcher`,
/// `QueryDispatcher` and `EventPublisher`, which `CqrsDispatcher` implements, so
/// matching `CqrsDispatcher` alone would never fire against the real package.
const _dispatcherTypes = {
  'CqrsDispatcher',
  'CommandDispatcher',
  'QueryDispatcher',
  'EventPublisher',
};

/// The calls that make up the dispatcher's surface.
const _dispatcherCalls = {'command', 'query', 'publish', 'publishAll'};

/// The directory whose classes are use cases, by definition.
const _usecasesDirectory = 'usecases';

/// Reports a dispatch a feature should not be making.
class NoCqrsDispatchVisitor extends SimpleAstVisitor<void> {
  NoCqrsDispatchVisitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // A test drives the dispatcher on purpose; that is the seam being tested.
    if (context.isInTestDirectory) return;

    final element = node.methodName.element;
    if (element is! MethodElement) return;
    if (!_isDispatcherCall(element)) return;

    // Publishing is the module-to-module call the dispatcher is kept for, and a
    // use case is where it belongs.
    if (_isPublish(element.name) && _isInUsecases(context)) return;

    rule.reportAtNode(node);
  }
}

bool _isPublish(String? name) => name == 'publish' || name == 'publishAll';

bool _isInUsecases(RuleContext context) =>
    hasDirectory(context.definingUnit.file.path, _usecasesDirectory);

bool _isDispatcherCall(MethodElement element) {
  if (!_dispatcherCalls.contains(element.name)) return false;

  final owner = element.enclosingElement;
  if (owner is! InterfaceElement) return false;
  if (!isInCqrs(owner)) return false;

  return _dispatcherTypes.contains(owner.name) ||
      owner.allSupertypes.any(
        (type) => _dispatcherTypes.contains(type.element.name),
      );
}
