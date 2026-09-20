import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/error/error.dart';

import '../constants/rule_key.dart';
import '../visitors/layer_dependency_direction_visitor.dart';

/// A layer may not depend on a layer outside it.
///
/// This is the rule the layering exists for. `domain` holds the entities, the
/// repository interfaces and the use cases — the part of a feature that is
/// worth testing without a server, a database or a widget. The moment it names
/// an HTTP client or a screen, it can no longer be tested or replaced on its
/// own, and every layer above it inherits the coupling.
///
/// `presentation` reaching into `infrastructure` is the same break from the
/// other end: a view model that builds its own repository has taken over a
/// decision the feature's domain was supposed to own.
class LayerDependencyDirectionRule extends AnalysisRule {
  LayerDependencyDirectionRule()
    : super(
        name: RuleKey.layerDependencyDirection.value,
        description:
            'Disallows a feature layer from depending on a layer outside '
            'it: `domain` on `infrastructure` or `presentation`, and '
            '`presentation` on `infrastructure`.',
      );

  @override
  LintCode get diagnosticCode => LintCode(
    RuleKey.layerDependencyDirection.value,
    '`{0}` must not depend on `{1}`.',
    correctionMessage: 'Depend inward: reach `{1}` through `domain` instead.',
  );

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    // A test wires the real layers together on purpose: it is the composition
    // root for the case under test, and `test/` mirrors the feature layout.
    if (context.isInTestDirectory) return;

    // A file outside a feature layer — `core/`, `app/`, or a feature's module
    // file — is not part of the layering this rule describes.
    final from = layerOf(context.definingUnit.file.path);
    if (from == null) return;

    final visitor = LayerDependencyDirectionVisitor(this, from);
    registry.addImportDirective(this, visitor);
    registry.addExportDirective(this, visitor);
  }
}
