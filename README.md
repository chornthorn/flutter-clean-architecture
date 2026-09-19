# flutter_x

A new Flutter project.

## Setup

Generated sources are not committed, so a fresh clone does not compile until
codegen has run once:

```bash
flutter pub get
dart run kaisel_generator                           # app registry + registered packages
dart run build_runner build                         # *.config.dart, *.cqrs.dart, *.g.dart
flutter test
```

Registering a micro-package is the only step that lives in the app: the app's run
scans a registered package that sits inside this project — `features/profile` —
and writes its manifest (`features/profile/lib/profile.kaisel.dart`) before
composing it. A package outside this project must generate (or ship) its own
manifest, since its sources are not this project's to write.

See `docs/architecture.md` for the architecture, and run codegen again after
adding a handler, an `@Injectable`, an endpoint, or a design token.

## Running

```bash
flutter run                          # reads jsonplaceholder over HTTP
flutter run --dart-define=DI_ENV=dev # the in-memory posts fixture, no network
```

`--dart-define=API_BASE_URL=...` points the HTTP adapter somewhere else.
