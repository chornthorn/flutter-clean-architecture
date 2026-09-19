# Core

Shared foundation. Something moves here only once **two or more features** need
it — one feature's code belongs inside that feature.

```
lib/core/
  execution/
    execution_context.dart   one screen's scope: the capture, its providers, its
                             cancellation. A `ProviderSession`, closed by the
                             route that owns the view model.
    execution_event.dart     what the capture records, in order
    execution_observer.dart  the SPI: who watches executions (providers, per
                             environment)
    executions.dart          creates one context per screen, holds the providers
    observers/               the observers: `TraceObserver` prints in dev
  networking/
    network_client.dart    the Dio every feature's endpoints shares, with its
                           timeouts and base URL. Bound in `provider.dart` —
                           features take it from the container, not from here.
    interceptors.dart      the cross-cutting layer: error mapping, logging.
                           Nothing per-endpoint belongs here.
    error_interceptor.dart transforms HTTP errors and responses into typed AppExceptions.
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

## Execution context

Every view model receives the dispatcher and an `ExecutionContext` through its
constructor — both declared with `super`, the way a widget takes its `key` — and
runs each user action through the context:

```dart
class PostViewModel extends ViewModel {
  PostViewModel({required super.dispatcher, required super.context});

  Future<void> loadPosts() async {
    _posts.setLoading();

    try {
      final posts = await context.run(
        () => dispatcher.query(GetPostsQuery(cancellation: context.cancellation)),
      );
      if (context.isCancelled) return;
      _posts.setValue(posts);
    } catch (error, stackTrace) {
      if (context.isCancelled || error is CancelledException) return;
      _posts.setError(error, stackTrace);
    }
  }
}
```

`run` captures while the work happens — the action's name (the calling method),
the providers it asked for, how long it took, how it ended — and rethrows what the
body threw, so error handling stays where it was. It decides nothing: an
`ExecutionObserver` provider reads the capture, and `DevExecutionObservers` prints
it in the dev environment:

```
▶ ctx-7 loadPosts
    · http-client/api
    ✔
◀ ctx-7 412ms
```

Rules worth knowing:

- **One context per view model**, created by DI (`Scope.factory`), closed by
  `ViewModel.dispose()`. A screen is a scope; a tap is an action inside it.
- **A closed context is frozen.** Once the route pops, `run` reports the
  cancellation, `fail`/`note` do nothing, and `isClosed` is what replaces a
  `_isDisposed` flag.
- **A body that swallows an error must report it** — `context.fail(error)` in the
  catch — or the capture says the action succeeded.
- **The context never reaches domain.** Queries still carry `Cancellation`; a
  `context` in a query is the next step, when an adapter needs the screen's
  providers.

## Error Handling Architecture

The architecture separates error responsibilities cleanly across layers without `throw mapDioErrorToFailure(error)` boilerplate:

```
[Dio / Network] -> [ErrorInterceptor] -> [AppException]
                          |
                   [Repository (.execute())] -> Domain Entities / AppException
                          |
                   [ViewModel / UseCases] -> ActionResult (Success / Failure)
                          |
                   [UI View / Dialog] -> AppFormScope / AppTextField / AppToast
```

1. **Dio ErrorInterceptor (`core/networking/error_interceptor.dart`)**:
   Intercepts network errors, timeouts, and HTTP status codes (400, 401, 403, 404, 422, 5xx), parses backend error envelopes (e.g. `{"message": "...", "errors": {...}}`), and attaches a strongly typed `AppException` to `DioException.error`.
2. **Safe Call Extension (`core/networking/try_safe_call.dart`)**:
   Extension on `Future<T>.guard()` that unboxes `DioException` and re-throws the attached `AppException`.
3. **Base Repository (`core/networking/repository.dart`)**:
   Abstract base class `Repository` provides `execute((token) => ..., cancellation: token)` which bridges domain `Cancellation` into Dio's `CancelToken` and applies `.guard()`, eliminating transport plumbing and keeping error handling explicit.
4. **Domain Validation (`core/error/app_exception.dart`)**:
   Domain business rules throw `ValidationException(message: ..., fieldErrors: ...)`. Because this class is pure Dart, Domain remains isolated from Flutter or IO.
5. **Action Outcomes (`core/presentation/action_result.dart`)**:
   Commands and ViewModels return `ActionResult` (`ActionSuccess`, `ActionFailure`), encapsulating user-facing messages and field error maps.
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

```dart
abstract interface class ViewModel {
  void dispose();
}
```

View models hold state in `Signal`s and `Computed`s from `package:signals`. A view
reads signals through `Watch` or `SignalBuilder` so only the widget that depends on
a changing signal rebuilds.

```dart
// A view model exposes signals:
class PostViewModel implements ViewModel {
  final posts = signal<AsyncState<List<Post>>>(const AsyncLoading());
  ...
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

- `domain/`: entities, use cases, repository contracts.
- `core/async/cancellation.dart`: for the token it hands to repository calls.
- `core/presentation/view_model.dart`: the `ViewModel` interface.
- `package:signals/signals.dart`: reactive primitives.

This keeps view models testable with plain `test()` without a widget tester.

## Cancellation

When a user leaves a screen, in-flight HTTP requests started by that screen are
cancelled through `Cancellation`:

1. The `ViewModel` creates a `CancellationSource`.
2. Every repository call receives `source.token`.
3. In `dispose()`, the view model calls `source.cancel()`.
4. The repository adapter passes the token to Dio's `CancelToken`.

```dart
// In a view model:
class PostViewModel implements ViewModel {
  final _cancellation = CancellationSource();

  Future<void> load() async {
    try {
      final posts = await _repository.allPosts(cancellation: _cancellation.token);
      this.posts.value = AsyncData(posts);
    } catch (e) {
      // If cancelled because the screen was popped, ignore.
      if (_cancellation.isCancelled) return;
      posts.value = AsyncError(e);
    }
  }

  @override
  void dispose() {
    _cancellation.cancel();
  }
}
```
