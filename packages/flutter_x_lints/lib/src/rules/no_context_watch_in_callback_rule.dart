import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/error/error.dart';

import '../constants/rule_key.dart';
import '../visitors/no_context_watch_in_callback_visitor.dart';

/// `context.watch` must not be called from an event handler.
///
/// `watch` registers the widget as a dependent of the value it reads, and the
/// framework only allows that while the widget is building. An event handler
/// runs later — after a tap, a keystroke — so the call throws where a tap
/// happened, in code that looked right when it was written.
///
/// The read belongs in `build`, where the widget already depends on the value,
/// and the handler should call a method on what `build` watched. A `builder`
/// callback is a different matter: it runs during build, so it is left alone.
class NoContextWatchInCallbackRule extends AnalysisRule {
  NoContextWatchInCallbackRule()
    : super(
        name: RuleKey.noContextWatchInCallback.value,
        description:
            'Disallows calling `context.watch` from a function literal '
            'passed to an `on...` argument, where the framework rejects it.',
      );

  @override
  LintCode get diagnosticCode => LintCode(
    RuleKey.noContextWatchInCallback.value,
    '`context.watch` cannot be called from an event handler.',
    correctionMessage:
        'Watch in `build`, and have the handler call the view model it read '
        'there.',
  );

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    registry.addMethodInvocation(this, NoContextWatchInCallbackVisitor(this));
  }
}
