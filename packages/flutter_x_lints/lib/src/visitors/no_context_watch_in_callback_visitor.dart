import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../utils/packages.dart';

/// The argument-name prefix that marks an event handler.
///
/// `onPressed`, `onTap`, `onChanged` — as opposed to `builder`, whose callback
/// runs *while* the widget builds, where `context.watch` is exactly right.
const _handlerPrefix = 'on';

/// Reports a `context.watch` reached from an event handler.
class NoContextWatchInCallbackVisitor extends SimpleAstVisitor<void> {
  NoContextWatchInCallbackVisitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name != 'watch') return;
    if (!_isBuildContext(node.target?.staticType)) return;
    if (!_isInsideEventHandler(node)) return;

    rule.reportAtNode(node);
  }
}

bool _isBuildContext(DartType? type) {
  if (type is! InterfaceType) return false;

  return _isBuildContextClass(type.element) ||
      type.allSupertypes.any((type) => _isBuildContextClass(type.element));
}

bool _isBuildContextClass(InterfaceElement element) =>
    element.name == 'BuildContext' && isInPackage(element, 'flutter');

/// Whether [node] sits inside a function literal handed to an `on...` argument.
///
/// Every enclosing literal is checked, so a `watch` buried in a `setState`
/// inside an `onPressed` still counts. A declaration ends the search: a method
/// an event handler calls is not itself the handler.
bool _isInsideEventHandler(AstNode node) {
  for (
    AstNode? current = node.parent;
    current != null;
    current = current.parent
  ) {
    if (current is MethodDeclaration || current is FunctionDeclaration) {
      return false;
    }

    if (current is FunctionExpression) {
      if (current.parent case NamedArgument(:final name)) {
        if (name.lexeme.startsWith(_handlerPrefix)) return true;
      }
    }
  }

  return false;
}
