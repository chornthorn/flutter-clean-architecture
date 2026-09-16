# flutter_application_1

A new Flutter project.

## Setup

Generated sources are not committed, so a fresh clone does not compile until
codegen has run once:

```bash
flutter pub get
dart run build_runner build   # *.config.dart, *.cqrs.dart, app_theme.g.dart
flutter test
```

See `docs/architecture.md` for the architecture, and run codegen again after
adding a handler, an `@Injectable`, or a design token.
