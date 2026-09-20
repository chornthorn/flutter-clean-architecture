import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../utils/get_it.dart';
import '../utils/paths.dart';
import '../utils/widgets.dart';

/// The directory whose files are UI, whatever they declare.
const _uiDirectory = 'presentation';

/// Reports a reach for the service locator from a widget or a UI file, whether
/// the file imports `get_it` or resolves the instance through the app's own
/// container.
class NoGetItInUiVisitor extends SimpleAstVisitor<void> {
  NoGetItInUiVisitor(this.rule, this.context);

  final AnalysisRule rule;
  final RuleContext context;

  @override
  void visitImportDirective(ImportDirective node) {
    if (!isGetItUri(node.uri.stringValue)) return;
    if (!_isUi()) return;

    rule.reportAtNode(node);
  }

  /// `getIt.get<PostViewModel>()`, and the same through a longer path such as
  /// `GetIt.instance.get<PostViewModel>()`.
  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.target == null) return;
    if (!_isGetItType(node.target?.staticType)) return;
    if (!_isUi()) return;

    rule.reportAtNode(node);
  }

  /// `getIt<PostViewModel>()`: a call on the instance itself. The parser hands
  /// this over as the invocation of an expression, not as a method call, so it
  /// takes a second visit to see it.
  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    if (!_isGetItType(node.function.staticType)) return;
    if (!_isUi()) return;

    rule.reportAtNode(node);
  }

  /// Whether [type] is a `get_it` container.
  ///
  /// Resolved rather than matched by name: the import is not the thing to
  /// watch, because `provider.dart` hands the instance out and
  /// `getIt.get<PostViewModel>()` then needs no `get_it` import in sight.
  bool _isGetItType(DartType? type) {
    if (type is! InterfaceType) return false;

    return _isGetItClass(type.element) ||
        type.allSupertypes.any((supertype) => _isGetItClass(supertype.element));
  }

  bool _isGetItClass(InterfaceElement element) =>
      element.name == 'GetIt' && isInGetIt(element);

  bool _isUi() {
    // A widget can be declared anywhere: a design-system component under
    // `core/`, or a screen under `presentation/`.
    final unit = context.currentUnit?.unit;
    if (unit != null && declaresWidget(unit)) return true;

    // Not every UI file declares one. A view model or a form field is still UI,
    // and reaching for the locator from there hides a dependency just as well.
    return hasDirectory(context.definingUnit.file.path, _uiDirectory);
  }
}
