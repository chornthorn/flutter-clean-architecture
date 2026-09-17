import 'package:flutter/material.dart';
import 'package:kaisel/kaisel.dart';
import 'package:provider/provider.dart';
import 'package:signals/signals_flutter.dart';

import '../../../../app/app_route.dart';
import '../../../../core/design_system/app_theme.g.dart';
import '../../../../core/design_system/components/app_buttons.dart';
import '../../../../core/design_system/components/app_notice.dart';
import '../../../../core/design_system/components/app_scaffold.dart';
import '../../../../core/design_system/components/app_toast.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/presentation/action_result.dart';
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
    // Read once, subscribe never: `SignalBuilder` below does the rebuilding.
    final viewModel = context.read<PostsHomeViewModel>();
    final theme = context.theme;

    return SignalBuilder(
      builder: (context) => AppScaffold(
        title: const Text('Posts'),
        actions: [
          // Nothing to pop inside the feature, so this leaves it.
          IconButton(
            onPressed: () => context.router<AppRoute>().pop(),
            icon: const Icon(Icons.close),
            tooltip: 'Exit posts',
          ),
        ],
        body: _buildBody(context, viewModel),
        floatingActionButton: FloatingActionButton(
          // One write at a time: the form disables its own submit in flight, but it
          // can still be dismissed over one, and this is what stops a second write.
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

    // Data and error arms first: both reloading variants are `AsyncLoading`.
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
            // `PostDetail` is a `PostsRoute`, so this pushes inside the feature.
            onTap: () => _open(context, viewModel, post.id),
          );
        },
      ),
      AsyncError<List<Post>>(:final error) => AppNotice(
        icon: error is NetworkException
            ? Icons.wifi_off_outlined
            : Icons.cloud_off_outlined,
        message: error is AppException
            ? error.message
            : 'Could not load posts.',
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
          onSubmit: (title, body) async {
            final result = await viewModel.createPost(title: title, body: body);
            if (result case ActionSuccess(:final message)
                when message != null) {
              if (context.mounted) {
                AppToast.showSuccess(context, message);
              }
            }
            return result;
          },
        ),
      );
}
