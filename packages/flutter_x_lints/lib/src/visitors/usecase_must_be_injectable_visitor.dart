import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../utils/cqrs.dart';
import '../utils/injectify.dart';
import '../utils/paths.dart';

/// The handler contracts the `cqrs` package declares.
const _handlerContracts = {'CommandHandler', 'QueryHandler', 'EventHandler'};

/// The message contracts the `cqrs` package declares: what a handler takes.
const _messageContracts = {'Command', 'Query', 'Event'};

/// The directory whose classes are use cases, by definition.
const _usecasesDirectory = 'usecases';

/// Reports a use case the container cannot build.
class UsecaseMustBeInjectableVisitor extends SimpleAstVisitor<void> {
  UsecaseMustBeInjectableVisitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (!_isHandler(node) && !_isUseCase(context, node)) return;

    // A base the concrete use cases share is not built by the container; the
    // classes that extend it are.
    if (node.abstractKeyword != null) return;

    // A private class is the file's own helper, not something the container
    // hands a view model.
    if (node.namePart.typeName.lexeme.startsWith('_')) return;

    if (isAnnotatedInjectable(node)) return;

    rule.reportAtToken(node.namePart.typeName);
  }
}

/// Whether [node] is a use case by where it is declared.
///
/// The directory is the signal, as it is for view models: a class under
/// `usecases/` that is not one of the messages a handler takes is a use case,
/// and the container is what builds it.
bool _isUseCase(RuleContext context, ClassDeclaration node) {
  // A test declares fakes and doubles in a `usecases/` directory on purpose.
  if (context.isInTestDirectory) return false;
  if (!hasDirectory(context.definingUnit.file.path, _usecasesDirectory)) {
    return false;
  }

  return !_extendsOneOf(node, _messageContracts);
}

/// Whether [node] implements one of `cqrs`'s handler contracts.
///
/// Resolved, so a project's own `QueryHandler` look-alike is not mistaken for
/// the one the registry resolves.
bool _isHandler(ClassDeclaration node) =>
    _extendsOneOf(node, _handlerContracts);

/// Whether [node] extends, implements or mixes in any of [names] as declared by
/// the `cqrs` package.
bool _extendsOneOf(ClassDeclaration node, Set<String> names) {
  final element = node.declaredFragment?.element;
  if (element == null) return false;

  return element.allSupertypes.any(
    (type) => names.contains(type.element.name) && isInCqrs(type.element),
  );
}
