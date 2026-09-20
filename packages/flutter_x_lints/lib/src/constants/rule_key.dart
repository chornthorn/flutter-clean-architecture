/// The name of every rule this plugin reports.
///
/// One place, because a rule's name is its public identity: it is what
/// `analysis_options.yaml` enables and sets the severity of, what
/// `// ignore: flutter_x_lints/<name>` suppresses, and what a reader greps for.
/// Registering under one string and reporting under another would leave the
/// rule impossible to configure.
///
/// A rule builds its `LintCode` in `diagnosticCode` rather than holding one in
/// a `static const` field, which the analyzer's guide warns against. It is safe
/// here: `LintCode` implements `==` and `hashCode` on its name, and everything
/// that matches a code — the server's lookup, and `// ignore:` comments —
/// compares names rather than identity.
enum RuleKey {
  layerDependencyDirection('layer_dependency_direction'),
  noCqrsInWidgets('no_cqrs_in_widgets'),
  noDispatcherOutsideViewModel('no_dispatcher_outside_view_model'),
  noGetItInUi('no_get_it_in_ui'),
  viewModelExposesReadonlySignals('view_model_exposes_readonly_signals'),
  viewModelMustBeInjectable('view_model_must_be_injectable'),
  viewModelMustExtendBase('view_model_must_extend_base'),
  viewModelSignalsMustBePrivate('view_model_signals_must_be_private');

  const RuleKey(this.value);

  /// The rule's name, as `analysis_options.yaml` and `// ignore:` spell it.
  final String value;
}
