import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../utils/injectify.dart';
import '../utils/supertypes.dart';

/// Reports a view model the container cannot build.
class ViewModelMustBeInjectableVisitor extends SimpleAstVisitor<void> {
  ViewModelMustBeInjectableVisitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (!hasAnySupertype(node, const {'ViewModel'})) return;

    // A base the concrete view models share is not built by the container;
    // the classes that extend it are. Annotating it would ask injectify to
    // register something it cannot construct.
    if (node.abstractKeyword != null) return;

    if (isAnnotatedInjectable(node)) return;

    rule.reportAtToken(node.namePart.typeName);
  }
}
