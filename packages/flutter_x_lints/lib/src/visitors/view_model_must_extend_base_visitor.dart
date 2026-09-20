import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../utils/supertypes.dart';

/// The base class every view model inherits from.
const viewModelBase = 'ViewModel';

/// Reports a class declared in `view_models/` that is not a view model.
class ViewModelMustExtendBaseVisitor extends SimpleAstVisitor<void> {
  ViewModelMustExtendBaseVisitor(this.rule);

  final AnalysisRule rule;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final name = node.namePart.typeName.lexeme;

    // A `ViewModel` declared here is a base, not a view model that lost its
    // base. The app's own base sits outside this directory.
    if (name == viewModelBase) return;

    if (hasAnySupertype(node, const {viewModelBase})) return;

    rule.reportAtToken(node.namePart.typeName);
  }
}
