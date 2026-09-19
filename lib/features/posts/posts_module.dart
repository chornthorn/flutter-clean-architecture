import 'package:flutter/widgets.dart';
import 'package:injectify/injectify.dart';
import 'package:kaisel/kaisel.dart';
import 'package:kaisel_generator/kaisel_generator.dart';
import 'package:provider/provider.dart';

import '../../provider.dart';
import 'presentation/view_models/post_view_model.dart';
import 'presentation/views/post_detail_view.dart';
import 'presentation/views/posts_home_view.dart';

// The posts feature's entry point: its injectify micro-package and its routes.
@InjectableMicroPackage(moduleName: 'Posts')
void configurePostsModule() {}

sealed class PostsRoute extends KaiselRoute {
  const PostsRoute();
}

final class PostsHome extends PostsRoute {
  const PostsHome();
}

final class PostDetail extends PostsRoute {
  const PostDetail(this.id);

  final int id;

  @override
  List<Object?> get props => [id];
}

// Keep it `const`: kaisel rebuilds the router when the module instance changes.
@KaiselModule(prefix: '/posts')
class PostsRouterModule extends RouteModule<PostsRoute> {
  const PostsRouterModule();

  @override
  List<PostsRoute> get initialStack => const [PostsHome()];

  @override
  Widget buildPage(BuildContext context, PostsRoute route) => switch (route) {
    // `Provider` owns the view model's lifetime; the container does not dispose factories.
    PostsHome() => Provider<PostViewModel>(
      create: (_) => getIt<PostViewModel>()..load(),
      dispose: (_, viewModel) => viewModel.dispose(),
      child: const PostsHomeView(),
    ),
    PostDetail(:final id) => Provider<PostViewModel>(
      create: (_) => getIt<PostViewModel>()..load(id),
      dispose: (_, viewModel) => viewModel.dispose(),
      child: PostDetailView(id: id),
    ),
  };

  @override
  ModuleStackCodec<PostsRoute> get codec => const PostsRouteCodec();
}

// The `/posts` URL mapping.
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
