import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import '../cqrs.dart';
import '../supertypes.dart';

/// The Flutter bases a widget library declares. `State` is included because a
/// `State` class is where a widget's dispatch would most plausibly hide.
const _widgetBases = {'Widget', 'State', 'StatefulWidget', 'StatelessWidget'};

/// A library that declares a widget must not import CQRS.
///
/// This is the boundary the app's layering draws: a widget reads state and calls
/// methods on the view model that owns it, and every read and write goes through
/// the view model's dispatcher. A widget that holds a `Query` or a `Command` has
/// taken over a decision that belongs to its view model.
class NoCqrsInWidgets extends AnalysisRule {
  static const LintCode code = LintCode(
    'no_cqrs_in_widgets',
    'A library that declares a widget must not import CQRS.',
    correctionMessage:
        'Dispatch from the view model instead, and expose the outcome as state.',
  );

  NoCqrsInWidgets()
      : super(
          name: 'no_cqrs_in_widgets',
          description:
              'Disallows importing the cqrs package from a library that '
              'declares a widget, so dispatch stays in the view model.',
        );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _Visitor(this, context);
    registry.addImportDirective(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule, this.context);

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
    .any((declaration) => extendsAnyBase(declaration, _widgetBases));
