/// The analyzer plugin entry point.
///
/// The analysis server loads this file and reads the top-level [plugin]
/// variable, so the name and the location are both part of the contract.
library;

import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/rules/layer_dependency_direction_rule.dart';
import 'src/rules/no_cqrs_in_widgets_rule.dart';
import 'src/rules/no_dispatcher_outside_view_model_rule.dart';
import 'src/rules/no_get_it_in_ui_rule.dart';
import 'src/rules/view_model_exposes_readonly_signals_rule.dart';
import 'src/rules/view_model_must_extend_base_rule.dart';
import 'src/rules/view_model_signals_must_be_private_rule.dart';

final plugin = FlutterXLintsPlugin();

class FlutterXLintsPlugin extends Plugin {
  @override
  String get name => 'flutter_x_lints';

  @override
  void register(PluginRegistry registry) {
    // Lint rules: off unless `analysis_options.yaml` turns them on, so adding
    // one here never starts failing somebody else's build.
    registry.registerLintRule(LayerDependencyDirectionRule());
    registry.registerLintRule(NoCqrsInWidgetsRule());
    registry.registerLintRule(NoDispatcherOutsideViewModelRule());
    registry.registerLintRule(NoGetItInUiRule());
    registry.registerLintRule(ViewModelExposesReadonlySignalsRule());
    registry.registerLintRule(ViewModelMustExtendBaseRule());
    registry.registerLintRule(ViewModelSignalsMustBePrivateRule());
  }
}
