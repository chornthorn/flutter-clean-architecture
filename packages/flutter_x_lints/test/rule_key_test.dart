import 'package:flutter_x_lints/src/constants/rule_key.dart';
import 'package:test/test.dart';

void main() {
  test('should name each rule as the app configures it', () {
    // A rule's name is its public API: `analysis_options.yaml` enables it and
    // sets its severity by this string, and `// ignore:` suppresses it by this
    // string. A rename that misses the app's config disables the rule silently
    // — no diagnostic, no error — so pin the names here.
    expect(RuleKey.values.map((key) => key.value).toList(), [
      'layer_dependency_direction',
      'no_cqrs_in_widgets',
      'no_dispatcher_outside_view_model',
      'no_get_it_in_ui',
      'view_model_exposes_readonly_signals',
      'view_model_must_extend_base',
    ]);
  });
}
