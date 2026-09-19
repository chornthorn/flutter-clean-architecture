import 'package:flutter/material.dart';
import 'package:kaisel/kaisel.dart';
import 'package:provider/provider.dart';
import 'package:signals/signals_flutter.dart';

import '../../../../core/design_system/app_theme.g.dart';
import '../../../../core/design_system/components/app_buttons.dart';
import '../../../../core/design_system/components/app_card.dart';
import '../../../../core/design_system/components/app_notice.dart';
import '../../../../core/design_system/components/app_scaffold.dart';
import '../../../../core/design_system/components/app_toast.dart';
import '../../../../core/presentation/action_result.dart';
import '../../domain/entities/post.dart';
import '../view_models/comment_view_model.dart';
import '../view_models/post_view_model.dart';
import '../widgets/comments_section.dart';
import '../widgets/post_byline.dart';
import '../widgets/post_form_dialog.dart';

/// The post detail screen.
///
/// Dispatches queries, updates, and deletes through [PostViewModel], and reads
/// and adds comments through the [CommentViewModel] its route provides.
class PostDetailView extends StatelessWidget {
  const PostDetailView({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PostViewModel>();

    return SignalBuilder(
      builder: (context) {
        final state = viewModel.post.value;
        final post = state.value;
        // A write on the wire locks both actions: the page reads the write's
        // own state, so neither action starts a second one.
        final isWriting =
            viewModel.delete.value.isLoading ||
            viewModel.update.value.isLoading;

        return AppScaffold(
          title: Text('Post $id'),
          actions: [
            if (post != null) ...[
              IconButton(
                tooltip: 'Delete post',
                icon: const Icon(Icons.delete_outline),
                onPressed: isWriting
                    ? null
                    : () => _delete(context, viewModel, post),
              ),
              IconButton(
                tooltip: 'Edit post',
                icon: const Icon(Icons.edit_outlined),
                onPressed: isWriting
                    ? null
                    : () => _edit(context, viewModel, post),
              ),
            ],
          ],
          body: _buildBody(context, viewModel, state),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    PostViewModel viewModel,
    AsyncState<Post?> state,
  ) {
    final theme = context.theme;

    return switch (state) {
      AsyncData<Post?>(:final value) when value == null => const AppNotice(
        icon: Icons.article_outlined,
        message: 'Post not found.',
      ),
      AsyncData<Post?>(:final value) => SingleChildScrollView(
        // Post and thread scroll together: a thread of any length is the normal
        // case here, not the exception.
        padding: EdgeInsets.all(theme.sizes.padding.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value!.title, style: theme.typography.title.semiBold),
                  SizedBox(height: theme.sizes.spacing.sm),
                  PostByline(userId: value.userId),
                  const Divider(height: 24),
                  Text(value.body, style: theme.typography.body.regular),
                ],
              ),
            ),
            SizedBox(height: theme.sizes.spacing.md),
            CommentsSection(postId: id),
          ],
        ),
      ),
      AsyncError<Post?>() => AppNotice(
        icon: Icons.cloud_off_outlined,
        message: 'Could not load post.',
        isFailure: true,
        action: AppFilledButton(
          label: 'Try again',
          onPressed: () => viewModel.load(id),
        ),
      ),
      AsyncLoading<Post?>() => Center(
        child: CircularProgressIndicator(color: theme.colors.brand.primary),
      ),
    };
  }

  Future<void> _edit(
    BuildContext context,
    PostViewModel viewModel,
    Post post,
  ) async {
    viewModel.prepareEdit(post);
    await showDialog<void>(
      context: context,
      builder: (_) => PostFormDialog(
        heading: 'Edit post',
        submitLabel: 'Save',
        formController: viewModel.updateFormController,
        onSubmit: () async {
          final result = await viewModel.updatePost(post.id);
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

  Future<void> _delete(
    BuildContext context,
    PostViewModel viewModel,
    Post post,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this post?'),
        content: Text('Are you sure you want to delete "${post.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final result = await viewModel.deletePost(post.id);
      if (result case ActionSuccess(:final message) when message != null) {
        if (context.mounted) {
          AppToast.showSuccess(context, message);
          context.pop();
        }
      } else if (result case ActionFailure(:final message)) {
        if (context.mounted) {
          AppToast.showError(context, message);
        }
      }
    }
  }
}
