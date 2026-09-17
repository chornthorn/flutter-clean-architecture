import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:signals/signals_flutter.dart';

import '../../../../core/design_system/app_theme.g.dart';
import '../../../../core/design_system/components/app_buttons.dart';
import '../../../../core/design_system/components/app_card.dart';
import '../../../../core/design_system/components/app_notice.dart';
import '../../../../core/design_system/components/app_scaffold.dart';
import '../../../../core/design_system/components/app_toast.dart';
import '../../../../core/error/app_exception.dart';
import '../../../../core/presentation/action_result.dart';
import '../../domain/entities/post.dart';
import '../view_models/post_detail_view_model.dart';
import '../widgets/post_byline.dart';
import '../widgets/post_form_dialog.dart';

// Reads one post from `PostDetailViewModel` through signals: rebuilds when a
// signal emits, not when the view model says so.
class PostDetailView extends StatelessWidget {
  const PostDetailView({super.key, required this.id});

  // The id is a route parameter; the view model does not hold one of its own.
  final int id;

  @override
  Widget build(BuildContext context) {
    // Read once, rebuild through the SignalBuilder below. Subscribing to the
    // provider would rebuild the page on nothing, since the view model does not notify.
    final viewModel = context.read<PostDetailViewModel>();

    return SignalBuilder(
      builder: (context) => AppScaffold(
        title: Text('Post $id'),
        actions: _buildActions(context, viewModel),
        body: _buildBody(context, viewModel, viewModel.post.value),
      ),
    );
  }

  List<Widget> _buildActions(
    BuildContext context,
    PostDetailViewModel viewModel,
  ) {
    final post = viewModel.post.value.value;
    if (post == null) return const [];

    // The form keeps its submit button disabled while a write is on the wire,
    // and the page keeps its own action buttons disabled for the same reason: a
    // second write on the same entity would conflict with the first.
    final isWriting =
        viewModel.update.value.isLoading || viewModel.delete.value.isLoading;

    return [
      IconButton(
        onPressed: isWriting ? null : () => _edit(context, viewModel, post),
        icon: const Icon(Icons.edit_outlined),
        tooltip: 'Edit post',
      ),
      IconButton(
        onPressed: isWriting ? null : () => _delete(context, viewModel, post),
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Delete post',
      ),
    ];
  }

  Widget _buildBody(
    BuildContext context,
    PostDetailViewModel viewModel,
    AsyncState<Post?> state,
  ) {
    // `AsyncData*` first: the reloading and refreshing states implement `AsyncLoading`.
    return switch (state) {
      AsyncData<Post?>(:final value) when value != null => _buildPost(
        context,
        value,
      ),
      AsyncData<Post?>() => const AppNotice(
        icon: Icons.search_off_outlined,
        message: 'Post not found.',
      ),
      AsyncError<Post?>(:final error) => AppNotice(
        icon: error is NetworkException
            ? Icons.wifi_off_outlined
            : Icons.cloud_off_outlined,
        message: error is AppException ? error.message : 'Could not load post.',
        isFailure: true,
        action: AppFilledButton(
          label: 'Try again',
          onPressed: () => viewModel.load(id),
        ),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
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
    viewModel.form.clear();
    await showDialog<void>(
      context: context,
      builder: (_) => PostFormDialog(
        heading: 'Edit post',
        submitLabel: 'Save',
        initialTitle: post.title,
        initialBody: post.body,
        formController: viewModel.form,
        onSubmit: (title, body) async {
          final result = await viewModel.updatePost(
            post.id,
            title: title,
            body: body,
          );
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
    if (!context.mounted) return;

    final result = await viewModel.deletePost(post.id);

    if (result case ActionSuccess(:final message) when message != null) {
      if (context.mounted) {
        AppToast.showSuccess(context, message);
      }
    }

    if (result.isSuccess && context.mounted) {
      Navigator.of(context).pop();
    }
  }
}
