# flutter_x

A new Flutter project.

## Setup

Generated sources are not committed, so a fresh clone does not compile until
codegen has run once:

```bash
flutter pub get
dart run build_runner build   # *.config.dart, *.cqrs.dart, *.g.dart
flutter test
```

See `docs/architecture.md` for the architecture, and run codegen again after
adding a handler, an `@Injectable`, an endpoint, or a design token.

## Running

```bash
flutter run                          # reads jsonplaceholder over HTTP
flutter run --dart-define=DI_ENV=dev # the in-memory posts fixture, no network
```

`--dart-define=API_BASE_URL=...` points the HTTP adapter somewhere else.
