import 'package:flutter/material.dart';
import 'package:kaisel/kaisel.dart';
import 'package:provider/provider.dart';

import '../../../../app/app_route.dart';
import '../../../../core/design_system/app_theme.g.dart';
import '../../posts_module.dart';
import '../view_models/posts_home_view_model.dart';
import '../widgets/post_buttons.dart';
import '../widgets/post_form_dialog.dart';
import '../widgets/post_tile.dart';
import '../widgets/posts_notice.dart';

// The feature's list screen.
class PostsHomeView extends StatelessWidget {
  const PostsHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PostsHomeViewModel>();
    final theme = context.theme;

    return Scaffold(
      backgroundColor: theme.colors.canvas.primary,
      appBar: AppBar(
        title: const Text('Posts'),
        backgroundColor: theme.colors.surface.card,
        foregroundColor: theme.colors.foreground.primary,
        titleTextStyle: theme.typography.title.semiBold,
        elevation: 0,
        // The bar is a fixed token colour, and Material's scroll tint would
        // paint the generated scheme's colour over it.
        surfaceTintColor: Colors.transparent,
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _compose(context, viewModel),
        backgroundColor: theme.colors.action.filled,
        foregroundColor: theme.colors.foreground.inverse,
        tooltip: 'New post',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody(BuildContext context, PostsHomeViewModel viewModel) {
    final theme = context.theme;

    // Gated on `posts == null` so a refresh keeps the current list on screen
    // instead of flashing a spinner.
    if (viewModel.isLoading && viewModel.posts == null) {
      return Center(
        child: CircularProgressIndicator(color: theme.colors.brand.primary),
      );
    }

    // The list is the point of the screen, so a dead end here offers a way to
    // ask again rather than only reporting the failure.
    if (viewModel.error != null) {
      return PostsNotice(
        icon: Icons.cloud_off_outlined,
        message: 'Could not load posts.',
        isFailure: true,
        action: PostFilledButton(label: 'Try again', onPressed: viewModel.load),
      );
    }

    final posts = viewModel.posts ?? const [];
    if (posts.isEmpty) {
      return const PostsNotice(
        icon: Icons.article_outlined,
        message: 'No posts yet.',
      );
    }

    return ListView.separated(
      padding: EdgeInsets.all(theme.sizes.padding.md),
      itemCount: posts.length,
      separatorBuilder: (context, index) =>
          SizedBox(height: theme.sizes.spacing.sm),
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

  Future<void> _compose(BuildContext context, PostsHomeViewModel viewModel) =>
      showDialog<void>(
        context: context,
        builder: (_) => PostFormDialog(
          heading: 'New post',
          submitLabel: 'Create',
          onSubmit: (title, body) =>
              viewModel.createPost(title: title, body: body),
        ),
      );
}
