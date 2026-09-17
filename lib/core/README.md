# Core

Shared foundation. Something moves here only once **two or more features** need
it — one feature's code belongs inside that feature.

```
lib/core/
  networking/
    network_client.dart    the Dio every feature's endpoints shares, with its
                           timeouts and base URL. Bound in `provider.dart` —
                           features take it from the container, not from here.
    interceptors.dart      the cross-cutting layer: error mapping, logging.
                           Nothing per-endpoint belongs here.
    error_interceptor.dart transforms HTTP errors and responses into typed AppExceptions.
    safe_call.dart         Future<T>.guard() extension unwrapping DioException.
  error/
    app_exception.dart     plain Dart application exception hierarchy (NetworkException,
                           ValidationException, UnauthorizedException, NotFoundException, etc.).
  presentation/
    action_result.dart     ActionResult<T> (ActionSuccess, ActionFailure) for UI operations.
    view_model.dart        the lifecycle a page's state holder owes the route
                           that owns it — the one interface every view model
                           implements, and nothing else.
  design_system/
    theme-spec.schema.json names the token groups design_builder parses
    app.tokens.json        the token values, per mode — edit here
    app_theme.g.dart       generated — AppTheme and its provider
    components/            the shared controls every screen builds from (AppToast, etc.)
  async/
    cancellation.dart      the signal a screen hands down with its reads, so a
                           request is dropped when the screen goes away
  storage/                 arrives with the first persisted data: the database or
                           key-value stack features' repositories sit on
```

## Error Handling Architecture

The architecture separates error responsibilities cleanly across layers without `throw mapDioErrorToFailure(error)` boilerplate:

```
[Dio / Network] -> [ErrorInterceptor] -> [AppException]
                          |
                   [Repository (.guard())] -> Domain Entities / AppException
                          |
                   [ViewModel / UseCases] -> ActionResult (Success / Failure)
                          |
                   [UI View / Dialog] -> AppToast / Inline AppNotice
```

1. **Dio ErrorInterceptor (`core/networking/error_interceptor.dart`)**:
   Intercepts network errors, timeouts, and HTTP status codes (400, 401, 403, 404, 422, 5xx), parses backend error envelopes (e.g. `{"message": "...", "errors": {...}}`), and attaches a strongly typed `AppException` to `DioException.error`.
2. **Safe Call Extension (`core/networking/safe_call.dart`)**:
   Repositories call `.guard()` on Dio futures. This un-boxes `DioException` and re-throws the attached `AppException`. Repositories do not contain manual `try / catch DioException` boilerplate unless handling domain-specific semantics (e.g. 404 returning `null`).
3. **Domain Validation (`core/error/app_exception.dart`)**:
   Domain business rules throw `ValidationException(message: ..., fieldErrors: ...)`. Because this class is pure Dart, Domain remains isolated from Flutter or IO.
4. **Action Outcomes (`core/presentation/action_result.dart`)**:
   Commands and ViewModels return `ActionResult` (`ActionSuccess`, `ActionFailure`), encapsulating user-facing messages and field error maps.
5. **UI Layer (`core/design_system/components/app_toast.dart`)**:
   Views never inspect HTTP codes or stack traces. They display `AppToast.showSuccess` / `AppToast.showError` for transient operations, and show `AppNotice` with `error.message` for persistent view states.

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

## Cancellation

A `Future` cannot be cancelled — awaiting one only waits. So a read started by a
page that is then popped keeps running: the socket is read, the payload decoded,
the result handed to a view model nobody is watching. `dispose` stops the
_notification_, not the work.

`async/cancellation.dart` is what stops the work. A screen holds one source, hands
its token down with every read it starts, and cancels where its scope ends — a
view model's `dispose`, a dialog's `State.dispose`:

```dart
final _cancellation = CancellationSource();

try {
  final posts = await _dispatcher.query(
    GetPostsQuery(cancellation: _cancellation.token),
  );
  if (_isDisposed) return;
  _posts.setValue(posts);
} catch (error, stackTrace) {
  // A dropped read is not a failure: there is nobody left to report it to.
  // Everything else is.
  if (_isDisposed) return;
  _posts.setError(error, stackTrace);
}
```

`_posts` is the read's own signal and `_isDisposed` is the view model's flag, set
in `dispose` just before it cancels — so the check that drops the read and the
check that keeps a write off a disposed signal are the same one. See
`docs/architecture.md` for the rest of the shape.

The source is the end that cancels; `Cancellation` — a typedef for `Future<void>`
— is the end that travels, and the token is what goes down. A feature's `domain/`
contract takes `{Cancellation? cancellation}` and stays plain Dart. Domain reaches
into `core/` for that one file, which is the exception the rules at the bottom
record; the test enforces it. The adapter is where the signal becomes
transport-shaped — `RemotePostRepository._tokenFor` turns it into a Dio
`CancelToken`, and `@CancelRequest()` on the endpoint parameter is what makes the
generated client pass that token on. Without the annotation retrofit takes the
parameter and quietly drops it.

What it buys: a JSON payload is not decoded into a screen that is gone, and a
request nobody wants stops occupying a connection.

Every path takes a token — `PostApi`'s five endpoints and every method on
`PostRepository` — because any request can be dropped at the transport. Whether a
caller _should_ drop one is the caller's decision, and the shipped callers draw the
line at reads: a read dropped on the way out only wastes an answer nobody would
have seen, while a write dropped mid-flight may still land on the server, leaving
the app and the server disagreeing about what happened with nobody left to tell.
The post form keeps its submit button disabled until the call answers for the same
reason. A caller that knows what a half-applied write means for its own data can
hand a token to a write; nothing else has to change.

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
  `domain/` — with two exceptions: `async/cancellation.dart` and `core/error/app_exception.dart`.
  These files are plain Dart over `dart:core`/`dart:async` with zero Flutter or IO dependencies.
  `test/architecture_test.dart` enforces this boundary.
- Presentation may import `core/` for the design system, action results, and cancellation.
