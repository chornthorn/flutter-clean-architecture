import 'package:kaisel/kaisel.dart';

// The host's sealed route family: one mount marker per feature.
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

final class PostsMount extends AppRoute {
  const PostsMount();
}
