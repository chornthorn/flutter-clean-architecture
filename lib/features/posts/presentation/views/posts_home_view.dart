import 'package:flutter/material.dart';
import 'package:kaisel/kaisel.dart';
import 'package:provider/provider.dart';
import 'package:signals/signals_flutter.dart';

import '../../../../app/app_route.dart';
import '../../../../core/design_system/app_theme.g.dart';
import '../../../../core/design_system/components/app_buttons.dart';
import '../../../../core/design_system/components/app_notice.dart';
import '../../../../core/design_system/components/app_scaffold.dart';
import '../../domain/entities/post.dart';
import '../../posts_module.dart';
import '../view_models/posts_home_view_model.dart';
import '../widgets/post_form_dialog.dart';
import '../widgets/post_tile.dart';

// The feature's list screen.
class PostsHomeView extends StatelessWidget {
  const PostsHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    // Read once, subscribe never: what changes lives in the view model's
    // signals, and `SignalBuilder` is what rebuilds this page off the ones read
    // below. It spans the whole screen because the action and the body answer to
    // different signals.
    final viewModel = context.read<PostsHomeViewModel>();
    final theme = context.theme;

    return SignalBuilder(
      builder: (context) => AppScaffold(
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
        body: _buildBody(context, viewModel),
        floatingActionButton: FloatingActionButton(
          // One write at a time from this screen. The form disables its own
          // submit while one is in flight, but it can still be dismissed over
          // it, and this is what stops a second write from there.
          onPressed: viewModel.create.value.isLoading
              ? null
              : () => _compose(context, viewModel),
          backgroundColor: theme.colors.action.filled,
          foregroundColor: theme.colors.foreground.inverse,
          tooltip: 'New post',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, PostsHomeViewModel viewModel) {
    final theme = context.theme;

    // `AsyncDataReloading` and `AsyncDataRefreshing` implement `AsyncLoading`, so
    // the arms that carry a value or a failure have to come before the loading
    // one — matching the loading arm first would swallow them.
    return switch (viewModel.posts.value) {
      AsyncData<List<Post>>(:final value) when value.isEmpty => const AppNotice(
        icon: Icons.article_outlined,
        message: 'No posts yet.',
      ),
      AsyncData<List<Post>>(:final value) => ListView.separated(
        padding: EdgeInsets.all(theme.sizes.padding.md),
        itemCount: value.length,
        separatorBuilder: (context, index) =>
            SizedBox(height: theme.sizes.spacing.sm),
        itemBuilder: (context, index) {
          final post = value[index];
          return PostTile(
            post: post,
            // `PostDetail` belongs to `PostsRoute`, so this pushes inside the
            // feature rather than on the host stack.
            onTap: () => _open(context, viewModel, post.id),
          );
        },
      ),
      // The list is the point of the screen, so a dead end here offers a way to
      // ask again rather than only reporting the failure.
      AsyncError<List<Post>>() => AppNotice(
        icon: Icons.cloud_off_outlined,
        message: 'Could not load posts.',
        isFailure: true,
        action: AppFilledButton(label: 'Try again', onPressed: viewModel.load),
      ),
      AsyncLoading<List<Post>>() => Center(
        child: CircularProgressIndicator(color: theme.colors.brand.primary),
      ),
    };
  }

  // Opens the post, then reads the list again once that page comes back. kaisel
  // keeps this page mounted underneath, so a write made up there leaves it
  // showing what it showed before — nothing remounts, nothing asks again. The
  // pop is the ask, and `push` settles when the navigation is applied rather
  // than on the way back, so waiting for one takes `pushForResult`.
  Future<void> _open(
    BuildContext context,
    PostsHomeViewModel viewModel,
    int id,
  ) async {
    await context.pushForResult<void>(PostDetail(id));

    // The feature can be left with the detail still up, which takes this page
    // with it.
    if (!context.mounted) return;

    await viewModel.load();
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
