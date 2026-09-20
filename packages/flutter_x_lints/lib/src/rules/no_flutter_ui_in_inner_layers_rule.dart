import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/error/error.dart';

import '../constants/rule_key.dart';
import '../utils/layers.dart';
import '../visitors/no_flutter_ui_in_inner_layers_visitor.dart';

/// The layers that must stay free of Flutter's UI.
const _frameworkFreeLayers = {'domain', 'infrastructure'};

/// `domain` and `infrastructure` must not depend on Flutter's UI.
///
/// `domain` holds the entities, the repository interfaces and the use cases, and
/// `infrastructure` implements those interfaces against the network, a database
/// or a file. Neither draws anything. The moment one of them imports a widget
/// package — or `dart:ui` for a `Color`, which is the same dependency wearing a
/// smaller hat — it can no longer be tested or replaced without a binding, and
/// the layer above inherits the coupling.
///
/// The rule is the UI half of the layering: `layer_dependency_direction` keeps
/// the layers pointing at each other correctly, and this keeps the inner ones
/// off the framework.
class NoFlutterUiInInnerLayersRule extends AnalysisRule {
  NoFlutterUiInInnerLayersRule()
    : super(
        name: RuleKey.noFlutterUiInInnerLayers.value,
        description:
            'Disallows importing Flutter\'s widget packages, or `dart:ui`, '
            'from a `domain` or `infrastructure` layer.',
      );

  @override
  LintCode get diagnosticCode => LintCode(
    RuleKey.noFlutterUiInInnerLayers.value,
    '`{0}` must not depend on Flutter\'s UI.',
    correctionMessage:
        'Keep the layer free of widgets, or move the code that draws into '
        '`presentation`.',
  );

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final layer = layerOf(context.definingUnit.file.path);
    if (layer == null || !_frameworkFreeLayers.contains(layer)) return;

    final visitor = NoFlutterUiInInnerLayersVisitor(this, layer);
    registry.addImportDirective(this, visitor);
    registry.addExportDirective(this, visitor);
  }
}
