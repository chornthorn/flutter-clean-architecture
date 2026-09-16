import 'package:flutter/widgets.dart';
import 'package:injectify/injectify.dart';
import 'package:kaisel/kaisel.dart';
import 'package:provider/provider.dart';

import '../../provider.dart';
import 'presentation/view_models/post_detail_view_model.dart';
import 'presentation/view_models/posts_home_view_model.dart';
import 'presentation/views/post_detail_view.dart';
import 'presentation/views/posts_home_view.dart';

// The posts feature's injectify micro-package: every `@Injectable` class under
// `lib/features/posts/` is registered by this module and by nothing else.
@InjectableMicroPackage(moduleName: 'Posts')
void configurePostsModule() {}

// Routes for the posts feature.
sealed class PostsRoute extends KaiselRoute {
  const PostsRoute();
}

final class PostsHome extends PostsRoute {
  const PostsHome();
}

final class PostDetail extends PostsRoute {
  const PostDetail(this.id);

  final int id;

  // Equality is by `props`.
  @override
  List<Object?> get props => [id];
}

// Kaisel module for the posts feature. Keep it `const` — kaisel rebuilds the
// router when the module instance changes.
class PostsRouterModule extends RouteModule<PostsRoute> {
  const PostsRouterModule();

  @override
  List<PostsRoute> get initialStack => const [PostsHome()];

  @override
  Widget buildPage(BuildContext context, PostsRoute route) => switch (route) {
    // `Provider`, not `ChangeNotifierProvider`: the view model publishes signals
    // rather than notifying, so what it needs from here is an owner for its
    // lifetime and not a listener. `dispose:` is how the page leaving reaches
    // it — the container's factory scope does not dispose what it builds.
    PostsHome() => Provider<PostsHomeViewModel>(
      create: (_) => getIt<PostsHomeViewModel>()..load(),
      dispose: (_, viewModel) => viewModel.dispose(),
      child: const PostsHomeView(),
    ),
    PostDetail(:final id) => Provider<PostDetailViewModel>(
      create: (_) => getIt<PostDetailViewModel>()..load(id),
      dispose: (_, viewModel) => viewModel.dispose(),
      child: PostDetailView(id: id),
    ),
  };

  @override
  ModuleStackCodec<PostsRoute> get codec => const PostsRouteCodec();
}

// URL mapping under the `/posts` prefix.
class PostsRouteCodec extends ModuleStackCodec<PostsRoute> {
  const PostsRouteCodec();

  // The composer can hand this another feature's stack for one frame.
  @override
  List<String> encodeAny(List<KaiselRoute> stack) {
    final top = stack.last;
    if (top is! PostsRoute) return const [];
    return encode(<PostsRoute>[top]);
  }

  @override
  List<String> encode(List<PostsRoute> stack) => switch (stack.last) {
    PostsHome() => const [],
    PostDetail(:final id) => ['$id'],
  };

  @override
  List<PostsRoute>? decode(List<String> segments) => switch (segments) {
    [] => const [PostsHome()],
    // A segment that is not a number is not a post id, so the URL is not ours.
    [final id] when int.tryParse(id) != null => [
      const PostsHome(),
      PostDetail(int.parse(id)),
    ],
    _ => null,
  };
}
