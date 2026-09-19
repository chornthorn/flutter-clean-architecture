import 'package:flutter/material.dart';
import 'package:kaisel/kaisel.dart';
import 'package:kaisel_generator/kaisel_generator.dart';

export 'profile.kaisel.dart';

// ---------------------------------------------------------------------------
// Profile Micro-Package Declaration
// ---------------------------------------------------------------------------
// This package is a micro-package: `dart run kaisel_generator` here writes
// `profile.kaisel.dart` exposing `ProfileKaiselModule`, which the host app
// registers in `@KaiselInit(externalMicroPackages: [...])`.
@KaiselMicroPackage(moduleName: 'Profile')
void configureProfileModule() {}

// ---------------------------------------------------------------------------
// Sealed Route Hierarchy for Profile Feature
// ---------------------------------------------------------------------------
sealed class ProfileRoute extends KaiselRoute {
  const ProfileRoute();
}

final class ProfileOverviewRoute extends ProfileRoute {
  const ProfileOverviewRoute();
}

final class ProfileEditRoute extends ProfileRoute {
  const ProfileEditRoute();
}

// ---------------------------------------------------------------------------
// Route Codec for Profile Feature
// ---------------------------------------------------------------------------
class ProfileRouteCodec extends ModuleStackCodec<ProfileRoute> {
  const ProfileRouteCodec();

  @override
  List<String> encode(List<ProfileRoute> stack) => switch (stack.last) {
        ProfileOverviewRoute() => const [],
        ProfileEditRoute() => const ['edit'],
      };

  @override
  List<ProfileRoute>? decode(List<String> segments) => switch (segments) {
        [] => const [ProfileOverviewRoute()],
        ['edit'] => const [ProfileOverviewRoute(), ProfileEditRoute()],
        _ => null,
      };
}

// ---------------------------------------------------------------------------
// Profile Feature RouteModule
// ---------------------------------------------------------------------------
@KaiselModule(prefix: '/profile', mount: 'ProfileMount', codec: ProfileRouteCodec)
class ProfileRouterModule extends RouteModule<ProfileRoute> {
  const ProfileRouterModule();

  @override
  List<ProfileRoute> get initialStack => const [ProfileOverviewRoute()];

  @override
  ModuleStackCodec<ProfileRoute> get codec => const ProfileRouteCodec();

  @override
  Widget buildPage(BuildContext context, ProfileRoute route) => switch (route) {
        ProfileOverviewRoute() => const Scaffold(
            body: Center(child: Text('Profile Overview')),
          ),
        ProfileEditRoute() => const Scaffold(
            body: Center(child: Text('Edit Profile')),
          ),
      };
}
