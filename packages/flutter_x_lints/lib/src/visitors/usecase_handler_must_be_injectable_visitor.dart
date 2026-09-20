import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../utils/cqrs.dart';
import '../utils/injectify.dart';

/// The handler contracts the `cqrs` package declares.
const _handlerContracts = {'CommandHandler', 'QueryHandler', 'EventHandler'};

/// Reports a use case handler the container cannot build.
class UsecaseHandlerMustBeInjectableVisitor extends SimpleAstVisitor<void> {
  UsecaseHandlerMustBeInjectableVisitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (!_isHandler(node)) return;

    // A base the concrete handlers share is not built by the container; the
    // classes that extend it are.
    if (node.abstractKeyword != null) return;

    if (isAnnotatedInjectable(node)) return;

    rule.reportAtToken(node.namePart.typeName);
  }
}

/// Whether [node] implements one of `cqrs`'s handler contracts.
///
/// Resolved, so a project's own `QueryHandler` look-alike is not mistaken for
/// the one the registry resolves.
bool _isHandler(ClassDeclaration node) {
  final element = node.declaredFragment?.element;
  if (element == null) return false;

  return element.allSupertypes.any(
    (type) =>
        _handlerContracts.contains(type.element.name) && isInCqrs(type.element),
  );
}
