import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/error/error.dart';

import '../constants/rule_key.dart';
import '../visitors/view_model_writable_signals_must_be_private_visitor.dart';

/// A view model's writable signals must be private fields.
///
/// A writable signal held publicly is part of the surface a view builds
/// against, and the view can set it: state changed behind the view model's
/// back, with no cancellation and no error path. Held privately, the view model
/// is the only thing that writes it, and the getter beside it decides what the
/// view is allowed to read.
///
/// A read-only signal is a different matter and is left alone. A `Computed` or
/// a `ReadonlySignal` field cannot be written through, so there is nothing to
/// hide behind a private name.
class ViewModelWritableSignalsMustBePrivateRule extends AnalysisRule {
  ViewModelWritableSignalsMustBePrivateRule()
    : super(
        name: RuleKey.viewModelWritableSignalsMustBePrivate.value,
        description:
            'Requires every writable signal field of a `ViewModel` subclass '
            'to be private.',
      );

  @override
  LintCode get diagnosticCode => LintCode(
    RuleKey.viewModelWritableSignalsMustBePrivate.value,
    'A view model\'s writable signals must be private.',
    correctionMessage:
        'Rename the field `_name`, and expose a `ReadonlySignal` getter if the '
        'view needs to read it.',
  );

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addClassDeclaration(
      this,
      ViewModelWritableSignalsMustBePrivateVisitor(this),
    );
  }
}
