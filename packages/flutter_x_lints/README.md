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
    utils/                       one file per concept: cqrs, get_it, signals, widgets,
                                 supertypes, paths, packages
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

| Rule                                          | Reports                                                                                                                          |
| :-------------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------- |
| `layer_dependency_direction`                  | A feature layer imports a layer outside it.                                                                                      |
| `no_cqrs_in_widgets`                          | A library that declares a `Widget` (or `State`) imports `package:cqrs`.                                                          |
| `no_context_watch_in_callback`                | `context.watch` is called inside a function literal passed to an `on...` argument.                                               |
| `no_dispatcher_outside_view_model`            | `CqrsDispatcher.command`/`.query` is called outside a `ViewModel` subclass, outside `test/`.                                     |
| `no_get_it_in_ui`                             | A library that declares a widget, or a file under `presentation/`, imports `package:get_it` or calls through a `GetIt` instance. |
| `view_model_exposes_readonly_signals`         | A `ViewModel` getter exposes a writable signal rather than a `ReadonlySignal`.                                                   |
| `view_model_must_be_injectable`               | A concrete `ViewModel` subclass is not annotated `@Injectable`.                                                                  |
| `view_model_must_extend_base`                 | A class declared under a `view_models/` directory does not extend or implement `ViewModel`.                                      |
| `view_model_writable_signals_must_be_private` | A `ViewModel` has a public field whose type is a writable signal.                                                                |

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

### How `no_get_it_in_ui` finds UI

Two signals, because either alone misses something:

- **The library declares a widget.** Catches widgets anywhere, including a
  design-system component under `core/` that no folder rule would reach.
- **The file is under a `presentation/` directory.** Catches the UI files that
  declare no widget — a view model, a form field — where the locator hides a
  dependency just as well.

Within those, two things are reported:

- **Importing `package:get_it`.** The file is set up to resolve its own
  dependencies.
- **Calling through a `GetIt` instance** — `getIt.get<PostViewModel>()` or
  `getIt<PostViewModel>()`. This is the reach that no import check can see,
  because `provider.dart` hands the instance out: a presentation file can
  resolve a screen's dependency without `get_it` appearing anywhere in it. The
  callee is resolved by type, so a `get` on anything else is left alone.

A feature's module file is out of scope: that is where a route's provider builds
the screen. So is `test/`, and `domain/` — keeping the locator out of `domain` is
`test/architecture_test.dart`'s job, which checks that layer by folder.

### How `view_model_exposes_readonly_signals` decides

By the type the getter returns, resolved — not by how the field was built, and
not by what the body looks like:

| Return type         |                                               |
| :------------------ | :-------------------------------------------- |
| `ReadonlySignal<T>` | fine                                          |
| `Computed<T>`       | fine — it extends `ReadonlySignal`            |
| `AsyncSignal<T>`    | reported — it extends `Signal<AsyncState<T>>` |
| `Signal<T>`         | reported                                      |

It applies to a class that extends or implements `ViewModel`, and to public
getters only: a `_private` getter is the view model's own business. Reporting at
the return type keeps the fix to the type — the body still reads `=> _posts`.

### How `view_model_writable_signals_must_be_private` decides

A field of a `ViewModel` whose resolved type is a **writable** signal must be
private. The type is resolved, so an inferred `final posts = asyncSignal(...)`
counts the same as a written annotation.

| Field type          |                                               |
| :------------------ | :-------------------------------------------- |
| `AsyncSignal<T>`    | reported — it extends `Signal<AsyncState<T>>` |
| `Signal<T>`         | reported                                      |
| `Computed<T>`       | fine — read-only                              |
| `ReadonlySignal<T>` | fine — read-only                              |

A read-only signal cannot be written through, so there is nothing to hide behind
a private name. A writable one held publicly is part of the surface a view
builds against, and the view can set it.

Statics and locals are not part of the view's surface and are left alone.
Together with `view_model_exposes_readonly_signals` this leaves one way to
_change_ state from outside a view model: none.

### How `no_context_watch_in_callback` decides

The call must be `watch`, its receiver must resolve to Flutter's
`BuildContext`, and it must sit inside a function literal handed to an argument
whose name starts with `on` — `onPressed`, `onTap`, `onChanged`.

The `on` prefix is what separates the two kinds of callback. An `on...` handler
runs after the build, when `watch` throws; a `builder:` callback runs _during_
build, where `watch` is exactly right. Matching on "any function literal" would
have flagged `builder:` too.

Every enclosing literal is checked, so a `watch` buried in a `forEach` inside an
`onPressed` still counts. A declaration ends the search: a method the handler
calls is not itself the handler.

### How `view_model_must_be_injectable` decides

The annotation is resolved to `Injectable` in the `injectify` package, so a
same-named annotation from elsewhere does not satisfy it — that class registers
nothing. Arguments are not required: `@Injectable()`, `@Injectable(scope: ...)`
and a constructor tear-off all count.

Two exemptions:

- The base `ViewModel` itself, which does not extend `ViewModel`.
- An `abstract` view model. The container builds the concrete subclasses, and
  asking injectify to register something it cannot construct fails later.

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
      no_context_watch_in_callback: error
      no_cqrs_in_widgets: error
      no_dispatcher_outside_view_model: error
      no_get_it_in_ui: error
      view_model_exposes_readonly_signals: error
      view_model_must_be_injectable: error
      view_model_must_extend_base: error
      view_model_writable_signals_must_be_private: error
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
