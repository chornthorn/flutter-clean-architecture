import 'package:kaisel/kaisel.dart';

// The host's routes: one mount marker per feature, and nothing else. Each
// feature's own routes live in its own sealed type.
sealed class AppRoute extends KaiselRoute {
  const AppRoute();
}

final class HomeMount extends AppRoute {
  const HomeMount();
}

final class ShopMount extends AppRoute {
  const ShopMount();
}

final class SettingsMount extends AppRoute {
  const SettingsMount();
}
