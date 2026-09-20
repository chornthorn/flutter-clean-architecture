import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/error/error.dart';

import '../constants/rule_key.dart';
import '../visitors/view_model_exposes_readonly_signals_visitor.dart';

/// A view model's public getters must expose read-only signals.
///
/// A view model owns its state: it starts the read, it applies the outcome, and
/// it decides what a failure means. A view handed a writable `Signal` can set
/// that state behind the view model's back — no cancellation, no error path,
/// and a page whose state no longer matches the work that produced it.
///
/// `ReadonlySignal` reads the same way and cannot be written, which is why the
/// view model keeps the `AsyncSignal` private and hands out a getter.
class ViewModelExposesReadonlySignalsRule extends AnalysisRule {
  ViewModelExposesReadonlySignalsRule()
    : super(
        name: RuleKey.viewModelExposesReadonlySignals.value,
        description:
            'Requires every public getter of a `ViewModel` subclass to '
            'expose a read-only signal rather than a writable one.',
      );

  @override
  LintCode get diagnosticCode => LintCode(
    RuleKey.viewModelExposesReadonlySignals.value,
    'A view model must expose a `ReadonlySignal`.',
    correctionMessage:
        'Type the getter `ReadonlySignal<...>`, and keep the writable signal '
        'private.',
  );

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addClassDeclaration(
      this,
      ViewModelExposesReadonlySignalsVisitor(this),
    );
  }
}
