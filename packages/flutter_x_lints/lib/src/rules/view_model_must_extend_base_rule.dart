import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/error/error.dart';

import '../constants/rule_key.dart';
import '../visitors/view_model_must_extend_base_visitor.dart';

/// The directory whose classes are view models, by definition.
const _viewModelsDirectory = 'view_models';

/// Every class declared under a `view_models/` directory must extend or
/// implement the base `ViewModel`.
///
/// The directory is the signal. "View model" is not a thing the analyzer can
/// see, and a name convention only covers the classes that follow it, so a file
/// in `view_models/` is taken to say what its classes are — and what it declares
/// is held to the contract.
///
/// The base hands a screen's state holder the app's dispatcher and the `dispose`
/// the route calls on unmount. A class that lives here without inheriting the
/// base takes on the screen's work without the screen's lifecycle, and the page
/// leaks whatever it started.
class ViewModelMustExtendBaseRule extends AnalysisRule {
  ViewModelMustExtendBaseRule()
    : super(
        name: RuleKey.viewModelMustExtendBase.value,
        description:
            'Requires every class declared under a `view_models/` directory '
            'to extend or implement the base `ViewModel` class.',
      );

  @override
  LintCode get diagnosticCode => LintCode(
    RuleKey.viewModelMustExtendBase.value,
    'A class in `view_models/` must extend or implement `ViewModel`.',
    correctionMessage:
        'Extend `ViewModel` and forward the dispatcher with '
        '`super.dispatcher`, or move the class out of `view_models/`.',
  );

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    // A test declares mocks and fakes in a `view_models/` directory on purpose.
    if (context.isInTestDirectory) return;
    if (!_isUnderViewModelDirectory(context.definingUnit.file.path)) return;

    registry.addClassDeclaration(this, ViewModelMustExtendBaseVisitor(this));
  }
}

/// Whether [path] has a `view_models` directory segment.
bool _isUnderViewModelDirectory(String path) =>
    path.replaceAll(r'\', '/').split('/').contains(_viewModelsDirectory);
