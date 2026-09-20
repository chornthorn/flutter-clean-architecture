import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../utils/cqrs.dart';
import '../utils/supertypes.dart';

/// The Flutter bases a widget library declares. `State` is included because a
/// `State` class is where a widget's dispatch would most plausibly hide.
const _widgetBases = {'Widget', 'State', 'StatefulWidget', 'StatelessWidget'};

/// Reports the CQRS import of a library that declares a widget.
class NoCqrsInWidgetsVisitor extends SimpleAstVisitor<void> {
  NoCqrsInWidgetsVisitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  @override
  void visitImportDirective(ImportDirective node) {
    if (!isCqrsUri(node.uri.stringValue)) return;

    // The import is reported, so the decision needs the whole library, not just
    // the directive: the widget it would leak into may be declared below it.
    final unit = context.currentUnit?.unit;
    if (unit == null) return;
    if (!_declaresWidget(unit)) return;

    rule.reportAtNode(node);
  }
}

bool _declaresWidget(CompilationUnit unit) => unit.declarations
    .whereType<ClassDeclaration>()
    .any((declaration) => hasAnySupertype(declaration, _widgetBases));
