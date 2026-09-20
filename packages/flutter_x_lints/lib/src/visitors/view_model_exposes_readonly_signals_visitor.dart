import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../utils/signals.dart';
import '../utils/supertypes.dart';

/// Reports a view model getter that hands out a signal the view can write to.
class ViewModelExposesReadonlySignalsVisitor extends SimpleAstVisitor<void> {
  ViewModelExposesReadonlySignalsVisitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (!hasAnySupertype(node, const {'ViewModel'})) return;

    for (final member in node.body.members) {
      if (member is! MethodDeclaration) continue;
      if (!member.isGetter) continue;
      // A private getter is the view model's own business.
      if (member.name.lexeme.startsWith('_')) continue;

      final returnType = member.declaredFragment?.element.returnType;
      if (!isWritableSignal(returnType)) continue;

      // Reported at the type: that is the part that has to change, and the
      // body keeps reading `=> _posts`.
      rule.reportAtNode(member.returnType ?? member);
    }
  }
}
