# Tests

`test/` mirrors `lib/`, so a file's counterpart is one path substitution away:

| `lib/`                                                             | `test/`                                                                 |
| :----------------------------------------------------------------- | :---------------------------------------------------------------------- |
| `app/app.dart`                                                     | `app/app_test.dart`, `app/app_codec_test.dart`                          |
| `features/shop/domain/usecases/get_product_query.dart`             | `features/shop/domain/usecases/get_product_query_test.dart`             |
| `features/shop/presentation/view_models/shop_home_view_model.dart` | `features/shop/presentation/view_models/shop_home_view_model_test.dart` |

Two kinds of file sit outside that mirror:

- `architecture_test.dart` — validates the _structure_ rather than testing a
  class, so it belongs to no single `lib/` file. It is the reason the rules in
  `docs/architecture.md` are enforced rather than aspirational.

There is no `support/` folder, because `lib/` has none. A shared test file lives
in the mirrored folder of whatever it stands in for:

| File                                                                 | Doubles                                                                                               |
| :------------------------------------------------------------------- | :---------------------------------------------------------------------------------------------------- |
| `app/view_host.dart`                                                 | pumps a page under a provider, in the app's token theme; `hostShell` is the same without a view model |
| `core/execution/execution_context_fixture.dart`                      | `testContext()` — the scope a view model built by hand needs (`context: testContext()`)               |
| `features/shop/domain/entities/product_fixture.dart`                 | the canonical `Product`                                                                               |
| `features/shop/domain/repositories/mock_product_repository.dart`     | `ProductRepository`                                                                                   |
| `features/shop/domain/repositories/mock_cart_repository.dart`        | `CartRepository`                                                                                      |
| `features/posts/infrastructure/repositories/fake_http_adapters.dart` | the recording and pending `HttpClientAdapter`s, plus the JSON body helper                             |

A view model test builds its view model with `context: testContext()` and does not
close the context by hand: `dispose` does that, exactly as the route does in the
app.
