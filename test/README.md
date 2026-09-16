# Tests

`test/` mirrors `lib/`, so a file's counterpart is one path substitution away:

| `lib/` | `test/` |
|:-------|:--------|
| `app/app_codec.dart` | `app/app_codec_test.dart` |
| `features/shop/domain/usecases/get_product_query.dart` | `features/shop/domain/usecases/get_product_query_test.dart` |
| `features/shop/presentation/view_models/shop_home_view_model.dart` | `features/shop/presentation/view_models/shop_home_view_model_test.dart` |

Two kinds of file sit outside that mirror:

- `architecture_test.dart` — validates the *structure* rather than testing a
  class, so it belongs to no single `lib/` file. It is the reason the rules in
  `docs/architecture.md` are enforced rather than aspirational.

There is no `support/` folder, because `lib/` has none. A shared test file lives
in the mirrored folder of whatever it stands in for:

| File | Doubles |
|:-----|:--------|
| `features/shop/domain/entities/product_fixture.dart` | the canonical `Product` |
| `features/shop/domain/repositories/mock_product_repository.dart` | `ProductRepository` |
| `features/shop/domain/repositories/mock_cart_repository.dart` | `CartRepository` |
| `features/shop/domain/repositories/mock_audit_log.dart` | `AuditLog` |
| `features/shop/shop_dispatcher_fixture.dart` | the shop's message path: a real dispatcher over the generated handler module |
| `features/shop/presentation/views/view_host.dart` | mounts a page under a provider, in the app's token theme |

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
- **Views** are pumped under `hostPage(...)` from
  `features/shop/presentation/views/view_host.dart`, which mounts a provider the
  way the feature's module does. No container there either — pass the view model
  you built.
