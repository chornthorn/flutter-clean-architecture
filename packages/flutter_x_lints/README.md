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

## Layout

```
lib/
  main.dart                      the plugin entry point: `plugin`, and `register`
  src/
    constants/rule_key.dart      every rule name, in one enum
    rules/*_rule.dart            one AnalysisRule per rule: name, LintCode, registration
    visitors/*_visitor.dart      one SimpleAstVisitor per rule: the actual checks
    utils/                       what the `cqrs` package looks like; supertypes, resolved
```

A rule file holds only the rule's identity — its `RuleKey`, its `LintCode`, and
what it registers — so a reader sees what the rule is before how it works. The
check itself lives in its visitor, which takes the rule as an `AnalysisRule` and
reports through it.

Every class is named after what it is: `XxxRule` and `XxxVisitor`, in `rules/`
and `visitors/` respectively, so a rule and the visitor that serves it are found
the same way.

Rule names live in `RuleKey` because a name is a rule's public API: it is what
`analysis_options.yaml` enables and sets the severity of, and what `// ignore:`
suppresses. A `LintCode` cannot be `const` once its name comes from the enum, and
that is safe — `LintCode` implements `==` and `hashCode` on its name, so the
analyzer matches codes by name rather than identity. `test/rule_key_test.dart`
pins the names, because a rename that misses the app's config would disable the
rule silently.

## The rules

| Rule                               | Reports                                                                                      |
| :--------------------------------- | :------------------------------------------------------------------------------------------- |
| `layer_dependency_direction`       | A feature layer imports a layer outside it.                                                  |
| `no_cqrs_in_widgets`               | A library that declares a `Widget` (or `State`) imports `package:cqrs`.                      |
| `no_dispatcher_outside_view_model` | `CqrsDispatcher.command`/`.query` is called outside a `ViewModel` subclass, outside `test/`. |
| `view_model_must_extend_base`      | A class declared under a `view_models/` directory does not extend or implement `ViewModel`.  |

All are lint rules, so they are **off** until `analysis_options.yaml` turns
them on — adding a rule to this package never starts failing an existing build.

### How `layer_dependency_direction` reads the layering

A file's layer is the directory segment after its feature: `features/<feature>/<layer>/`.
Dependencies point inward.

| Layer            | May depend on              |
| :--------------- | :------------------------- |
| `domain`         | `domain`                   |
| `infrastructure` | `domain`, `infrastructure` |
| `presentation`   | `domain`, `presentation`   |

The shared `core/` is a kernel both sides sit on, so it is outside the rule, as
are `app/` and a feature's own module file. Both `import` and `export` are
checked. Tests are exempt: `test/` mirrors the feature layout, and a test wires
the real layers together on purpose — the view model tests import the
infrastructure repositories they drive.

### How `view_model_must_extend_base` finds a view model

The directory, not the name: every class in a file under a `view_models/` folder
is held to the contract. "View model" is not something the analyzer can see, and
a name convention only covers the classes that already follow it, so the folder
is taken to say what its classes are.

Two exemptions:

- Files in a package's `test/` directory. A test declares mocks and fakes in a
  `view_models/` folder on purpose (`MockPostRepository` in
  `test/features/posts/presentation/view_models/`).
- A class named exactly `ViewModel`, which is a base rather than a view model
  that lost its base.

Enums, mixins and extensions in the folder are not classes and are not checked.

## Enabling it

In the app's `analysis_options.yaml` (top-level `plugins` key, _not_ under
`analyzer`):

```yaml
plugins:
  flutter_x_lints:
    path: packages/flutter_x_lints
    diagnostics:
      layer_dependency_direction: error
      no_cqrs_in_widgets: error
      no_dispatcher_outside_view_model: error
      view_model_must_extend_base: error
```

A relative `path` works, so this is safe to commit.

### Severity

Each rule takes a severity rather than only on/off, and the value is applied to
the diagnostic the server publishes:

| Value               | Effect                                                                     |
| :------------------ | :------------------------------------------------------------------------- |
| `error`             | Reported as an error; `dart analyze` / `flutter analyze` exit non-zero.    |
| `warning`           | Reported as a warning; the default `--fatal-warnings` still fails the run. |
| `info`              | Reported as an info.                                                       |
| `true`              | Enabled at the severity the rule declares.                                 |
| `false` / `disable` | Rule off.                                                                  |

So switching a rule between error and warning is a one-word edit. Rules left out
of `diagnostics` are off: a lint rule is never enabled implicitly.

Two things to know, both verified by hand:

- **Restart the analysis server** after changing the `plugins` section.
- **The analysis cache does not account for the plugin set.** Results computed
  before the plugin existed are reused, and the plugin's diagnostics are missing
  from them, even for files that have since changed. If a rule looks silent,
  clear `~/.dartServer/.analysis-driver` once; to confirm without touching it,
  run cold: `dart analyze --cache /tmp/some-fresh-dir`.

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
