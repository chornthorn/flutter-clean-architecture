# Core

Shared foundation. Something moves here only once **two or more features** need
it — one feature's code belongs inside that feature.

```
lib/core/
  networking/
    network_client.dart  the Dio every feature's endpoints shares, with its
                         timeouts and base URL. Bound in `provider.dart` —
                         features take it from the container, not from here.
    interceptors.dart    the cross-cutting layer: logging today, auth or retry
                         when they are needed. Nothing per-endpoint belongs here.
  design_system/
    theme-spec.schema.json  names the token groups design_builder parses
    app.tokens.json         the token values, per mode — edit here
    app_theme.g.dart        generated — AppTheme and its provider
    components/             the shared controls every screen builds from
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
3. `flutter test`. `flutter analyze` excludes generated files, so it cannot see a
   broken one — the test run is what compiles them. A group added to one mode and
   not the other generates a getter with no map behind it, and only shows up
   here.

`AppThemeNotifier` holds the mode and is owned by `KaiselApp`, not by the
container: a mode change has to rebuild `MaterialApp`, and only the widget tree
can do that. Screens call `context.themeNotifier.toggleMode()`.

## Components

A control two or more features need lives in `design_system/components/`; one a
single screen needs stays beside that screen, under
`features/<name>/presentation/widgets/`. That is the rule that moved the first
kit out of the posts feature once the shop and the host screens needed the same
chrome — and it is what keeps `PostTile`, `PostByline` and `PostAuthorBadge`
where they are.

Material is the bottom half of the design system, not the top. The generated
`ThemeData` carries `brightness` and the token extension and nothing else, so a
bare `FilledButton`, `Card`, `AppBar` or `TextField` takes its colours from
Material's generated scheme — a palette the token set never names, which also
survives a mode change untouched. A screen that wants the app's colours goes
through these components; when one is missing, add it here rather than styling a
Material widget at the call site.

`test/features/posts/presentation/widgets/post_tile_test.dart` is the guard on
that: it reads the card's fill and hairline off the theme, so a literal colour
fails the suite.

Two rules:

- `core/` must not import `features/`. It is the foundation — features depend on
  it, never the other way round. `test/architecture_test.dart` enforces this.
- Features reach into `core/` from their `infrastructure/` layer, never from
  `domain/`. A use case that imports an HTTP client has stopped being plain Dart.
  Presentation may import `core/` for the design system.
