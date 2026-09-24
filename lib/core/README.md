# Core

Shared foundation. Something moves here only once **two or more features** need
it — one feature's code belongs inside that feature.

```
lib/core/
  networking/
    network_client.dart    NetworkClient, the Dio every feature's endpoints
                           shares: timeouts, logging, and error mapping.
                           Bound in `provider.dart` — features take it from
                           the container, not from here.
    try_safe_call.dart     Future<T>.guard() extension unwrapping DioException.
    repository.dart        abstract base class for network repositories, bridging
                           cancellation and executing guarded API calls.
  error/
    app_exception.dart     plain Dart application exception hierarchy (NetworkException,
                           ValidationException, UnauthorizedException, NotFoundException, etc.).
  presentation/
    action_result.dart     ActionResult<T> (ActionSuccess, ActionFailure) for UI operations.
    view_model.dart        the lifecycle a page's state holder owes the route
                           that owns it — the one interface every view model
                           implements, and nothing else.
    form/
      app_form_scope.dart       AppFormScope & AppFormOptions built on top of Flutter's Form.
      app_form_controller.dart  manages server-side errors and owns the Flutter formKey.
      app_form_provider.dart    scoped InheritedNotifier isolating multiple forms on a screen.
  design_system/
    theme-spec.schema.json names the token groups design_builder parses
    app.tokens.json        the token values, per mode — edit here
    app_theme.g.dart       generated — AppTheme and its provider
    components/            the shared controls every screen builds from (AppToast, AppTextField, etc.)
  async/
    cancellation.dart      the signal a screen hands down with its reads, so a
                           request is dropped when the screen goes away
  storage/                 arrives with the first persisted data: the database or
                           key-value stack features' repositories sit on
```

## Error Handling Architecture

The architecture separates error responsibilities cleanly across layers without `throw mapDioErrorToFailure(error)` boilerplate:

```
[Dio / Network] -> [NetworkClient] -> [AppException]
                          |
                   [Repository (.execute())] -> Domain Entities / AppException
                          |
                   [ViewModel / UseCases] -> ActionResult (Success / Failure)
                          |
                   [UI View / Dialog] -> AppFormScope / AppTextField / AppToast
```

1. **NetworkClient (`core/networking/network_client.dart`)**:
   Intercepts network errors, timeouts, and HTTP status codes (400, 401, 403, 404, 422, 5xx), parses backend error envelopes (e.g. `{"message": "...", "errors": {...}}`), and attaches a strongly typed `AppException` to `DioException.error`.
2. **Safe Call Extension (`core/networking/try_safe_call.dart`)**:
   Extension on `Future<T>.guard()` that unboxes `DioException` and re-throws the attached `AppException`.
3. **Base Repository (`core/networking/repository.dart`)**:
   Abstract base class `Repository` provides `execute((token) => ..., cancellation: token)` which bridges domain `Cancellation` into Dio's `CancelToken` and applies `.guard()`, eliminating transport plumbing and keeping error handling explicit.
4. **Domain Validation (`core/error/app_exception.dart`)**:
   Domain business rules throw `ValidationException(message: ..., fieldErrors: ...)`. Because this class is pure Dart, Domain remains isolated from Flutter or IO.
5. **Action Outcomes (`core/presentation/action_result.dart`)**:
   ViewModels return `ActionResult` (`ActionSuccess`, `ActionFailure`), encapsulating user-facing messages and field error maps. Use cases throw; the view model is what turns a throw into a result the page can render.
6. **Scoped Form Errors (`core/presentation/form/` & `core/design_system/components/app_text_field.dart`)**:
   - `AppFormScope`: wraps Flutter's `Form` with all parameters bundled under `options: AppFormOptions` and bridges server errors via `AppFormProvider`. Automatically defaults `Form.key` to `controller.formKey`.
   - `AppFormController`: reactive state holding field-level error messages and owning `formKey` (`GlobalKey<FormState>`). Provides convenience methods `validate()`, `save()`, and `reset()`.
   - `AppFormProvider`: `InheritedNotifier` scoping form state down a widget subtree, enabling multiple forms on one screen without error collisions.
   - `AppTextField`: design-system compliant text input that binds automatically to `AppFormProvider` by `fieldKey` and clears its server error immediately upon editing.
7. **UI Layer (`core/design_system/components/app_toast.dart`)**:
   Views never inspect HTTP codes or stack traces. They display `AppToast.showSuccess` / `AppToast.showError` for transient operations, and show `AppNotice` with `error.message` for persistent view states.

## Design tokens

No widget hardcodes a color, a spacing, or a text style. Values live in
`app.tokens.json` and reach the UI through `app_theme.g.dart`:

- `theme.colors`: primary, surface, background, outline, text, error.
- `theme.spacing`: fine, tight, standard, double, quadruple.
- `theme.radius`: card, button, tag.
- `theme.typography`: headline, title, body, caption.

The theme switches between light and dark without touching widget code:
`AppThemeScope` listens to the system brightness, derives the matching token set,
and hands it to `AppTheme.of(context)`. Widgets read tokens through the extension
on `BuildContext`:

```dart
// Preferred: read through the context extension.
final colors = context.colors;
final spacing = context.spacing;

// Or via the inherited widget directly:
final theme = AppTheme.of(context);
```

To add a token: edit `app.tokens.json`, run `dart run build_runner build`, and use
the generated accessor. Never read raw colors or hardcode `EdgeInsets.all(16)`.

## View model lifecycle

A view model is scoped to its route. When the route is pushed, the container
creates it; when the route is popped, the container calls `dispose()`.

The base owns the scope and ends it before the subclass releases anything, so a
response that lands after the page is gone finds `isAlive` false and has nowhere
to write. A subclass never writes the cancel itself:

```dart
abstract class ViewModel {
  final _scope = CancellationSource();

  @protected
  Cancellation get cancellation => _scope.token;

  @protected
  bool get isAlive => !_scope.isCancelled;

  @nonVirtual
  void dispose() {
    if (!isAlive) return;
    _scope.cancel();
    onDispose();
  }

  @protected
  void onDispose() {}
}
```

`cancellation` goes to every use case, so the request is dropped at the
transport; `isAlive` is read after every `await`, before touching a signal or a
form controller — a write to a disposed signal throws
`SignalsWriteAfterDisposeError`, in release as well as debug.

```dart
@Injectable(scope: Scope.factory)
class PostViewModel extends ViewModel {
  final _posts = asyncSignal<List<Post>>(AsyncState.loading());

  Future<void> loadPosts() async {
    _posts.setLoading();
    try {
      final posts = await _getPosts(cancellation: cancellation);
      if (!isAlive) return;
      _posts.setValue(posts);
    } catch (error, stackTrace) {
      if (!isAlive || error is CancelledException) return;
      _posts.setError(error, stackTrace);
    }
  }

  @override
  void onDispose() => _posts.dispose();
}
```

View models hold state in `Signal`s and `Computed`s from `package:signals`. A view
reads signals through `Watch` or `SignalBuilder` so only the widget that depends on
a changing signal rebuilds.

```dart
// A view model exposes signals:
class PostViewModel extends ViewModel {
  final _posts = asyncSignal<List<Post>>(AsyncState.loading());

  ReadonlySignal<AsyncState<List<Post>>> get posts => _posts;
}

// The view watches them:
class PostsHomeView extends StatelessWidget {
  Widget build(BuildContext context) {
    return Watch((context) {
      final state = viewModel.posts.value;
      return switch (state) {
        AsyncData(:final value) => PostList(value),
        AsyncError(:final error) => AppNotice.error(error.toString()),
        _ => const CircularProgressIndicator(),
      };
    });
  }
}

```

A view model never imports Flutter widgets (`package:flutter/material.dart`,
etc.). It imports only:

- `domain/`: entities and the use cases it was built with.
- `core/presentation/view_model.dart`: the `ViewModel` base, which is where the
  token and `isAlive` come from.
- `package:signals/signals.dart`: reactive primitives.

This keeps view models testable with plain `test()` without a widget tester.

## Cancellation

When a user leaves a screen, in-flight HTTP requests started by that screen —
reads and writes alike — are cancelled through `Cancellation`:

1. The `ViewModel` base creates a `CancellationSource` and exposes its token as
   `cancellation`.
2. Every use case call receives `cancellation`, and every use case hands it to
   the repository.
3. `dispose()` cancels the scope first, then calls `onDispose()`.
4. The repository adapter passes the token to Dio's `CancelToken`.

```dart
// In a view model:
class PostViewModel extends ViewModel {
  PostViewModel(this._getPosts);

  final GetPostsUseCase _getPosts;

  Future<void> load() async {
    try {
      final posts = await _getPosts(cancellation: cancellation);
      if (!isAlive) return;
      this.posts.value = AsyncData(posts);
    } catch (e) {
      // If dropped because the screen was popped, publish nothing.
      if (!isAlive) return;
      posts.value = AsyncError(e);
    }
  }

  @override
  void onDispose() {
    posts.dispose();
  }
}
```
