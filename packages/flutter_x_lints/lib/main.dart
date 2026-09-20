/// The analyzer plugin entry point.
///
/// The analysis server loads this file and reads the top-level [plugin]
/// variable, so the name and the location are both part of the contract.
library;

import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/rules/no_cqrs_in_widgets.dart';
import 'src/rules/no_dispatcher_outside_view_model.dart';

final plugin = FlutterXLintsPlugin();

class FlutterXLintsPlugin extends Plugin {
  @override
  String get name => 'flutter_x_lints';

  @override
  void register(PluginRegistry registry) {
    // Lint rules: off unless `analysis_options.yaml` turns them on, so adding
    // one here never starts failing somebody else's build.
    registry.registerLintRule(NoCqrsInWidgets());
    registry.registerLintRule(NoDispatcherOutsideViewModel());
  }
}
