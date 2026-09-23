# flutter_x

A new Flutter project.

## Setup

Generated sources are not committed, so a fresh clone does not compile until
codegen has run once:

```bash
flutter pub get
dart run build_runner build   # every generator, including kaisel
flutter test
```

Kaisel runs inside build_runner: the builder hands the module registry
(`lib/app/app_modules.g.dart`) to build_runner, which owns and rewrites that file.
Registering a micro-package is the only step that lives in the app — the
generator scans a registered package that sits inside this project
(`features/profile`) and writes its manifest
(`features/profile/lib/profile.kaisel.dart`), which build_runner cannot do for
another package. To remove generated kaisel files:

```bash
dart run kaisel_generator --clean   # registry + every *.kaisel.dart manifest
dart run build_runner clean         # ...then this, before the next build
```

See `docs/architecture.md` for the architecture, and run codegen again after
adding a use case, an `@Injectable`, an endpoint, or a design token.

## Running

```bash
flutter run                          # reads jsonplaceholder over HTTP
flutter run --dart-define=DI_ENV=dev # the in-memory posts and comments fixture, no network
```

`--dart-define=API_BASE_URL=...` points the HTTP adapter somewhere else.
