import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../utils/signals.dart';
import '../utils/supertypes.dart';

/// Reports a public writable-signal field on a view model.
class ViewModelSignalsMustBePrivateVisitor extends SimpleAstVisitor<void> {
  ViewModelSignalsMustBePrivateVisitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (!hasAnySupertype(node, const {'ViewModel'})) return;

    for (final member in node.body.members) {
      if (member is! FieldDeclaration) continue;

      for (final variable in member.fields.variables) {
        final name = variable.name.lexeme;
        if (name.startsWith('_')) continue;

        // Resolved, so an inferred `final posts = asyncSignal(...)` counts the
        // same as a written annotation.
        final type = variable.declaredFragment?.element.type;
        if (!isWritableSignal(type)) continue;

        rule.reportAtToken(variable.name);
      }
    }
  }
}
