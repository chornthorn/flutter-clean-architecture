import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/error/error.dart';

import '../constants/rule_key.dart';
import '../visitors/view_model_must_be_injectable_visitor.dart';

/// A view model must be annotated `@Injectable`.
///
/// Nothing constructs a view model by hand: the router's provider asks the
/// container for one when a screen mounts, and that is what the annotation
/// generates. A view model without it compiles and then fails at the moment the
/// screen is opened — or worse, is reached for through the service locator
/// instead, which is the reach `no_get_it_in_ui` forbids.
///
/// A test is the one place a view model is built by hand on purpose, so a
/// package's `test/` directory is exempt.
class ViewModelMustBeInjectableRule extends AnalysisRule {
  ViewModelMustBeInjectableRule()
    : super(
        name: RuleKey.viewModelMustBeInjectable.value,
        description:
            'Requires every concrete `ViewModel` subclass to be annotated '
            '`@Injectable` so the container can build it.',
      );

  @override
  LintCode get diagnosticCode => LintCode(
    RuleKey.viewModelMustBeInjectable.value,
    'A view model must be annotated `@Injectable`.',
    correctionMessage:
        'Add `@Injectable(scope: Scope.factory)` above the class, so the '
        'router\'s provider can ask the container for it.',
  );

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    // A test constructs a view model directly, and a double it declares is not
    // something the container ever builds.
    if (context.isInTestDirectory) return;

    registry.addClassDeclaration(this, ViewModelMustBeInjectableVisitor(this));
  }
}
