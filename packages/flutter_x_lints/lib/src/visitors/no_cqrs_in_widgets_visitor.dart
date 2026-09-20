import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import '../utils/cqrs.dart';
import '../utils/widgets.dart';

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
    if (!declaresWidget(unit)) return;

    rule.reportAtNode(node);
  }
}
