# Tests

`test/` mirrors `lib/`, so a file's counterpart is one path substitution away:

| `lib/`                                                             | `test/`                                                                 |
| :----------------------------------------------------------------- | :---------------------------------------------------------------------- |
| `app/app_codec.dart`                                               | `app/app_codec_test.dart`                                               |
| `features/shop/domain/usecases/get_product_query.dart`             | `features/shop/domain/usecases/get_product_query_test.dart`             |
| `features/shop/presentation/view_models/shop_home_view_model.dart` | `features/shop/presentation/view_models/shop_home_view_model_test.dart` |

Two kinds of file sit outside that mirror:

- `architecture_test.dart` — validates the _structure_ rather than testing a
  class, so it belongs to no single `lib/` file. It is the reason the rules in
  `docs/architecture.md` are enforced rather than aspirational.

There is no `support/` folder, because `lib/` has none. A shared test file lives
in the mirrored folder of whatever it stands in for:

| File                                                                          | Doubles                                                                                               |
| :---------------------------------------------------------------------------- | :---------------------------------------------------------------------------------------------------- |
| `app/view_host.dart`                                                          | pumps a page under a provider, in the app's token theme; `hostShell` is the same without a view model |
| `features/shop/domain/entities/product_fixture.dart`                          | the canonical `Product`                                                                               |
| `features/shop/domain/repositories/mock_product_repository.dart`              | `ProductRepository`                                                                                   |
| `features/shop/domain/repositories/mock_cart_repository.dart`                 | `CartRepository`                                                                                      |
| `features/shop/domain/repositories/mock_audit_log.dart`                       | `AuditLog`                                                                                            |
| `features/shop/shop_dispatcher_fixture.dart`                                  | the shop's message path: a real dispatcher over the generated handler module                          |
| `features/posts/domain/entities/post_fixture.dart`                            | the canonical `Post`                                                                                  |
| `features/posts/domain/repositories/mock_post_repository.dart`                | `PostRepository`                                                                                      |
| `features/posts/posts_dispatcher_fixture.dart`                                | the posts message path: a real dispatcher over the generated handler module                           |
| `features/posts/infrastructure/repositories/remote_post_repository_test.dart` | a fake `HttpClientAdapter`, so the generated client is exercised with no socket                       |

Mocks come from `mocktail`, and they mock the **domain contract**, never the
adapter: a test that stubs `ProductRepository` keeps passing when
`InMemoryProductRepository` is replaced by a real one.

Views and view models are tested on the **real** message path —
`shop_dispatcher_fixture.dart` builds a dispatcher over the generated handler
module, and only the repositories behind it are mocks. A handler the generator
fails to register then shows up as a `HandlerNotFoundException` in a fast test,
not in the app.

```dart
final repository = MockProductRepository();
when(() => repository.allProducts()).thenAnswer((_) async => const [product]);

verify(() => repository.allProducts()).called(1);
```

Four `mocktail` behaviours worth knowing before you write a stub:

- `verify` **consumes** the calls it matches, so assert a call count once, at the
  end of a flow — not as a checkpoint partway through.
- `thenThrow` throws synchronously. It is fine when a `try` wraps the call, but
  for a `Future`-returning method use
  `thenAnswer((_) async => throw Exception('offline'))`, which is also what a
  real repository does.
- An **unstubbed** method returns `null`, which for a `Future<void>` surfaces as
  `type 'Null' is not a subtype of type 'Future<void>'` from inside the mock. Stub
  every method the code under test will reach.
- `any()` needs `registerFallbackValue` for **your own** types — `Cart`, not
  `String`. Call it once in `setUpAll`.

Two test styles, by layer:

- **Domain and view models** are plain Dart: build the class, call it, assert.
  No widgets, no container.
- **Views** are pumped under `hostSignalPage(...)` from `app/view_host.dart`, which
  mounts a provider the way a feature's module does and carries the app's token
  theme. No container there either — pass the view model you built. It does not
  listen to that provider, so a page that does not rebuild off its own signals
  shows what it shows. A widget that needs the theme but no view model (a dialog)
  goes under `hostShell(...)`.

**The container is built in `test`, never `prod`.** `configureDependencies`
requires an environment, and `Environment.test` is the one that binds the
in-memory posts adapter — which is what keeps the suite off the network. The one
place an adapter's class name may appear is a test asserting the _binding_ itself
(`features/posts/posts_module_test.dart`).

## Patrol finders

Widget tests may use Patrol's finder syntax instead of `find.*` — same
`flutter test` run, but the test reads closer to what a user does:

```dart
patrolWidgetTest('should say so when there is nothing to show', ($) async {
  final repository = MockPostRepository();
  when(() => repository.allPosts(cancellation: any(named: 'cancellation')))
      .thenAnswer((_) async => const []);
  final viewModel = PostViewModel(postsDispatcher(repository));
  addTearDown(viewModel.dispose);
  await viewModel.load();

  await $.pumpWidgetAndSettle(hostSignalPage(viewModel, const PostsHomeView()));

  expect($('No posts yet.').exists, isTrue);
  expect($(PostTile).exists, isFalse);
});
```

`$('text')`, `$(Type)`, and `$(#key)` replace their `find.*` counterparts, and
chain with `.$(...)` and `.containing(...)`; `tap()` and `enterText()` pump and
settle for you. Anything the finder cannot express is still reachable through
`$.tester`. Most tests stay on `find.*`; the two styles mix freely in one file —
this is an alternative, not a migration.

`patrolWidgetTest` comes from `package:patrol/patrol.dart` and needs no
`patrol_cli` and no native project changes — it runs under plain `flutter test`.
Native automation (`patrolTest`: permissions, notifications, real devices) is
not set up here.

Patrol's `patrol_log` still pins `equatable ^2.1.0`, so `pubspec.yaml` overrides
`equatable` to the 3.x this project uses; the only API `patrol_log` touches is
`with Equatable`, which 3.x keeps. Drop the override once Patrol allows
equatable 3.
