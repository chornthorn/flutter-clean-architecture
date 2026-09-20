# flutter_x_lints

An analyzer plugin that enforces this app's layering with custom lint rules.

It is a spike: it works end-to-end, but it is not enabled in the app's
`analysis_options.yaml` yet.

## What it is

The Dart analysis server supports plugins since Dart 3.10 / Flutter 3.38
(this repo runs Dart 3.13.2). A plugin is a normal Dart package that:

- depends on `analysis_server_plugin` and `analyzer`,
- exposes a top-level `plugin` variable in `lib/main.dart`,
- extends `Plugin` and registers rules in `register`.

The server loads the plugin into its own isolate, so the rules report through
`dart analyze`, `flutter analyze`, and the IDE — no separate command, and no
`custom_lint`.

Rules see the **resolved** AST: `RuleContext` exposes `libraryElement`,
`package`, `typeProvider` and `typeSystem`, so a rule can resolve what a name
actually refers to instead of matching text.

## The rules

| Rule | Reports |
| :--- | :--- |
| `no_cqrs_in_widgets` | A library that declares a `Widget` (or `State`) imports `package:cqrs`. |
| `no_dispatcher_outside_view_model` | `CqrsDispatcher.command`/`.query` is called outside a `ViewModel` subclass, outside `test/`. |

Both are lint rules, so they are **off** until `analysis_options.yaml` turns
them on — adding a rule to this package never starts failing an existing build.

## Enabling it

In the app's `analysis_options.yaml` (top-level `plugins` key, *not* under
`analyzer`):

```yaml
plugins:
  flutter_x_lints:
    path: packages/flutter_x_lints
    diagnostics:
      no_cqrs_in_widgets: true
      no_dispatcher_outside_view_model: true
```

A relative `path` works, so this is safe to commit.

Two things to know, both verified by hand:

- **Restart the analysis server** after changing the `plugins` section.
- **The analysis cache does not account for the plugin set.** Results computed
  before the plugin existed are reused, and the plugin's diagnostics are missing
  from them. If a rule looks silent, clear `~/.dartServer/.analysis-driver`, or
  confirm with a cold run: `dart analyze --cache /tmp/some-fresh-dir`.

Suppress a rule like any other diagnostic, qualified by the plugin name:

```dart
// ignore: flutter_x_lints/no_cqrs_in_widgets
```

## Writing a rule

A rule is a class extending `AnalysisRule` plus a visitor extending
`SimpleAstVisitor`:

```dart
class MyRule extends AnalysisRule {
  static const LintCode code = LintCode('my_rule', 'Message.');

  MyRule() : super(name: 'my_rule', description: 'Longer description.');

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    final visitor = _Visitor(this, context);
    registry.addImportDirective(this, visitor);
  }
}
```

The `LintCode` must be a single `static const` instance, or `// ignore:`
comments cannot match it. Register the rule with `registerLintRule` (opt-in) or
`registerWarningRule` (on by default).

## Testing a rule

`analyzer_testing` runs rules in-process, with mock `flutter`, `meta` and `ui`
packages available:

```dart
@reflectiveTest
class MyRuleTest extends AnalysisRuleTest {
  @override
  bool get addFlutterPackageDep => true;

  @override
  void setUp() {
    rule = MyRule();
    newPackage('cqrs')..addFile('lib/cqrs.dart', 'class CqrsDispatcher {}');
    super.setUp();
  }

  void test_something() async {
    await assertDiagnostics(source, [lint(offset, length)]);
  }
}
```

Test names must start with `test_`, which the naming lint dislikes — this
package's `analysis_options.yaml` turns that lint off for that reason.

## Gotchas

- **`print` does not work** in plugin code. Write to a file to debug.
- **The analyzer API moves fast and the docs lag.** The SDK's own
  `writing_rules.md` still shows `analyzer: ^8.0.0`; on Dart 3.13 the pairing is
  `analyzer: ^14.4.0` with `analysis_server_plugin: ^0.3.23`. `SimpleIdentifier`
  has `element`, not `staticElement`; `Element` has `library`, not
  `libraryFragment`.
- Plugins cannot be configured in a nested `analysis_options.yaml`.
- Fixes are offered through `ResolvedCorrectionProducer` +
  `registerFixForRule`; these two rules have none yet.
