import 'package:flutter/material.dart';
import 'package:kaisel/kaisel.dart';
import 'package:provider/provider.dart';

import '../../../../app/app_route.dart';
import '../../posts_module.dart';
import '../view_models/posts_home_view_model.dart';
import '../widgets/post_tile.dart';

// The feature's list screen.
class PostsHomeView extends StatelessWidget {
  const PostsHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PostsHomeViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Posts'),
        actions: [
          // The feature's inner navigator has nothing to pop here, so this
          // leaves the feature.
          IconButton(
            onPressed: () => context.router<AppRoute>().pop(),
            icon: const Icon(Icons.close),
            tooltip: 'Exit posts',
          ),
        ],
      ),
      body: _buildBody(context, viewModel),
    );
  }

  Widget _buildBody(BuildContext context, PostsHomeViewModel viewModel) {
    // Gated on `posts == null` so a refresh keeps the current list on screen
    // instead of flashing a spinner.
    if (viewModel.isLoading && viewModel.posts == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (viewModel.error != null) {
      return const Center(child: Text('Could not load posts.'));
    }

    final posts = viewModel.posts ?? const [];
    return ListView.builder(
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return PostTile(
          post: post,
          // `PostDetail` belongs to `PostsRoute`, so this pushes inside the
          // feature rather than on the host stack.
          onTap: () => context.push(PostDetail(post.id)),
        );
      },
    );
  }
}
