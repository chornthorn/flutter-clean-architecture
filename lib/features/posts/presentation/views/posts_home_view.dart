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
import '../../../../core/presentation/action_result.dart';
import '../../domain/entities/post.dart';
import '../../posts_module.dart';
import '../view_models/post_view_model.dart';
import '../widgets/post_form_dialog.dart';
import '../widgets/post_tile.dart';

class PostsHomeView extends StatelessWidget {
  const PostsHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PostViewModel>();

    return SignalBuilder(
      builder: (context) => AppScaffold(
        title: const Text('Posts'),
        actions: [
          IconButton(
            tooltip: 'New post',
            icon: const Icon(Icons.add),
            onPressed: () => _compose(context, viewModel),
          ),
          IconButton(
            onPressed: () => context.router<AppRoute>().pop(),
            icon: const Icon(Icons.close),
            tooltip: 'Exit posts',
          ),
        ],
        body: _buildBody(context, viewModel, viewModel.posts.value),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    PostViewModel viewModel,
    AsyncState<List<Post>> state,
  ) {
    final theme = context.theme;

    return switch (state) {
      AsyncData<List<Post>>(:final value) when value.isEmpty =>
        const AppNotice(
          icon: Icons.article_outlined,
          message: 'No posts yet.',
        ),
      AsyncData<List<Post>>(:final value) => _buildPosts(context, value),
      AsyncError<List<Post>>() => AppNotice(
        icon: Icons.cloud_off_outlined,
        message: 'Could not load posts.',
        isFailure: true,
        action: AppFilledButton(
          label: 'Try again',
          onPressed: viewModel.loadPosts,
        ),
      ),
      AsyncLoading<List<Post>>() => Center(
        child: CircularProgressIndicator(color: theme.colors.brand.primary),
      ),
    };
  }

  Widget _buildPosts(BuildContext context, List<Post> posts) {
    final theme = context.theme;

    return RefreshIndicator(
      onRefresh: () => _refresh(context.read<PostViewModel>()),
      child: ListView.separated(
        padding: EdgeInsets.all(theme.sizes.padding.md),
        itemCount: posts.length,
        separatorBuilder: (context, index) =>
            SizedBox(height: theme.sizes.spacing.sm),
        itemBuilder: (context, index) {
          final post = posts[index];
          return PostTile(
            post: post,
            onTap: () => context.push(PostDetail(post.id)),
          );
        },
      ),
    );
  }

  Future<void> _refresh(PostViewModel viewModel) async {
    viewModel.createFormController.clear();
    await viewModel.load();
  }

  Future<void> _compose(BuildContext context, PostViewModel viewModel) {
    viewModel.prepareCreate();
    return showDialog<void>(
      context: context,
      builder: (_) => PostFormDialog(
        heading: 'New post',
        submitLabel: 'Create',
        formController: viewModel.createFormController,
        onSubmit: () async {
          final result = await viewModel.createPost();
          if (result case ActionSuccess(:final message) when message != null) {
            if (context.mounted) {
              AppToast.showSuccess(context, message);
            }
          }
          return result;
        },
      ),
    );
  }
}
