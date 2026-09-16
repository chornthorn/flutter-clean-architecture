# Core

Shared foundation. Something moves here only once **two or more features** need
it — one feature's code belongs inside that feature.

```
lib/core/
  design_system/
    theme-spec.schema.json  names the token groups design_builder parses
    app.tokens.json         the token values, per mode — edit here
    app_theme.g.dart        generated — AppTheme and its provider
    components/             arrives with the second feature that needs the same control
  networking/               arrives with the first HTTP call: a base client and
                            interceptors shared by every feature's endpoints
  storage/                  arrives with the first persisted data: the database or
                            key-value stack features' repositories sit on
```

## Design tokens

No widget hardcodes a color, a spacing, or a text style. Values live in
`app.tokens.json` and reach the UI through `app_theme.g.dart`:

```dart
final theme = context.theme;
Container(color: theme.colors.surface.card, padding: EdgeInsets.all(theme.sizes.padding.md));
```

Flow:

1. Edit `app.tokens.json` (both `light` and `dark`). A new **group** also needs
   its name added to `theme-spec.schema.json` — the schema names groups, the
   tokens supply values, and a `$type` the schema doesn't define is skipped
   silently.
2. `dart run build_runner build`. The output is gitignored — there is nothing to
   commit — and `dart format` it only if you intend to read it.

`AppThemeNotifier` holds the mode and is owned by `KaiselApp`, not by the
container: a mode change has to rebuild `MaterialApp`, and only the widget tree
can do that. Screens call `context.themeNotifier.toggleMode()`.

Two rules:

- `core/` must not import `features/`. It is the foundation — features depend on
  it, never the other way round. `test/architecture_test.dart` enforces this.
- Features reach into `core/` from their `infrastructure/` layer, never from
  `domain/`. A use case that imports an HTTP client has stopped being plain Dart.
  Presentation may import `core/` for the design system.
