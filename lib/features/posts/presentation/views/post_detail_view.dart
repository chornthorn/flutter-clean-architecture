import 'package:flutter/material.dart';
import 'package:kaisel/kaisel.dart';
import 'package:provider/provider.dart';
import 'package:signals/signals_flutter.dart';

import '../../../../core/design_system/app_theme.g.dart';
import '../../../../core/design_system/components/app_card.dart';
import '../../../../core/design_system/components/app_toast.dart';
import '../../../../core/presentation/action_result.dart';
import '../../domain/entities/post.dart';
import '../view_models/post_detail_view_model.dart';
import '../widgets/post_byline.dart';
import '../widgets/post_form_dialog.dart';

/// The post detail screen.
///
/// Dispatches queries, updates, and deletes through [PostDetailViewModel].
class PostDetailView extends StatelessWidget {
  const PostDetailView({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PostDetailViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Post $id'),
        actions: [
          SignalBuilder(
            builder: (context) {
              final post = viewModel.post.value.value;
              if (post == null) return const SizedBox.shrink();

              final isWriting =
                  viewModel.update.value.isLoading ||
                  viewModel.delete.value.isLoading;

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit post',
                    onPressed: isWriting
                        ? null
                        : () => _edit(context, viewModel, post),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete post',
                    onPressed: isWriting
                        ? null
                        : () => _delete(context, viewModel, post),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: SignalBuilder(
        builder: (context) {
          final state = viewModel.post.value;

          return state.map(
            data: (post) => post == null
                ? const Center(child: Text('Post not found.'))
                : _buildPost(context, post),
            error: (error, _) => _buildError(context, viewModel),
            loading: () => const Center(child: CircularProgressIndicator()),
            reloading: () => const Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }

  Widget _buildError(BuildContext context, PostDetailViewModel viewModel) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Could not load post.'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => viewModel.load(id),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildPost(BuildContext context, Post post) {
    final theme = context.theme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            post.title,
            style: theme.typography.title.semiBold.copyWith(
              color: theme.colors.foreground.primary,
            ),
          ),
          const SizedBox(height: 8),
          PostByline(userId: post.userId),
          const SizedBox(height: 16),
          AppCard(
            child: Text(
              post.body,
              style: theme.typography.body.regular.copyWith(
                color: theme.colors.foreground.subtle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    PostDetailViewModel viewModel,
    Post post,
  ) async {
    viewModel.prepareEdit(post);
    await showDialog<void>(
      context: context,
      builder: (_) => PostFormDialog(
        heading: 'Edit post',
        submitLabel: 'Save',
        formController: viewModel.form,
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
    PostDetailViewModel viewModel,
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

    if (confirmed != true) return;

    final result = await viewModel.deletePost(post.id);
    if (!context.mounted) return;

    if (result.isSuccess) {
      if (result case ActionSuccess(:final message) when message != null) {
        AppToast.showSuccess(context, message);
      }
      context.pop();
    } else if (result case ActionFailure(:final message)) {
      AppToast.showError(context, message);
    }
  }
}
