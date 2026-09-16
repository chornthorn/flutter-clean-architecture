import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:signals/signals_flutter.dart';

import '../../../../core/design_system/app_theme.g.dart';
import '../../../../core/design_system/components/app_buttons.dart';
import '../../../../core/design_system/components/app_card.dart';
import '../../../../core/design_system/components/app_notice.dart';
import '../../../../core/design_system/components/app_scaffold.dart';
import '../../domain/entities/post.dart';
import '../view_models/post_detail_view_model.dart';
import '../widgets/post_byline.dart';
import '../widgets/post_form_dialog.dart';

// One post, looked up by the id carried on `PostDetail`.
class PostDetailView extends StatelessWidget {
  const PostDetailView({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context) {
    // Read once, subscribe never: `SignalBuilder` rebuilds this page off the signals read below.
    final viewModel = context.read<PostDetailViewModel>();

    return SignalBuilder(
      builder: (context) {
        final post = viewModel.post.value;

        return AppScaffold(
          title: Text('Post $id'),
          actions: _buildActions(context, viewModel, post),
          body: _buildBody(context, viewModel, post),
        );
      },
    );
  }

  List<Widget> _buildActions(
    BuildContext context,
    PostDetailViewModel viewModel,
    AsyncState<Post?> state,
  ) {
    // No actions until a post is on screen: the value is null while the read is
    // in flight, after a failure, and for an id that resolved to nothing.
    final post = state.value;
    if (post == null) return const [];

    // One write at a time; each use case's own signal says whether it is in flight.
    final isWriting =
        viewModel.update.value.isLoading || viewModel.delete.value.isLoading;

    return [
      IconButton(
        onPressed: isWriting ? null : () => _edit(context, viewModel, post),
        icon: const Icon(Icons.edit_outlined),
        tooltip: 'Edit post',
      ),
      IconButton(
        onPressed: isWriting ? null : () => _delete(context, viewModel),
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
    final theme = context.theme;

    // `AsyncData*` first: the reloading and refreshing states implement `AsyncLoading`.
    return switch (state) {
      AsyncData<Post?>(:final value) when value != null => _buildPost(
        context,
        value,
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
      // No post and no error means the id resolved to nothing, not worth a retry.
      AsyncData<Post?>() => const AppNotice(
        icon: Icons.search_off_outlined,
        message: 'Post not found.',
      ),
      AsyncLoading<Post?>() => Center(
        child: CircularProgressIndicator(color: theme.colors.brand.primary),
      ),
    };
  }

  Widget _buildPost(BuildContext context, Post post) {
    final theme = context.theme;

    return SingleChildScrollView(
      padding: EdgeInsets.all(theme.sizes.padding.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The title is the page's headline, so it sits on the canvas; the body is
          // content, so it takes a card, the way a row does in the list.
          Text(post.title, style: theme.typography.display.regular),
          SizedBox(height: theme.sizes.spacing.md),
          PostByline(userId: post.userId),
          SizedBox(height: theme.sizes.spacing.xl),
          AppCard(child: Text(post.body, style: theme.typography.body.regular)),
        ],
      ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    PostDetailViewModel viewModel,
    Post post,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => PostFormDialog(
        heading: 'Edit post',
        submitLabel: 'Save',
        initialTitle: post.title,
        initialBody: post.body,
        onSubmit: (title, body) =>
            viewModel.updatePost(title: title, body: body),
      ),
    );
  }

  Future<void> _delete(
    BuildContext context,
    PostDetailViewModel viewModel,
  ) async {
    final theme = context.theme;

    // Deleting is not undoable, so it asks first.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: theme.colors.surface.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(theme.sizes.radius.md),
        ),
        // The icon carries the danger colour, not the button: the token is a fill,
        // and its inverse pair sits under the contrast a label needs.
        icon: Icon(Icons.delete_outline, color: theme.colors.feedback.danger),
        title: Text(
          'Delete this post?',
          style: theme.typography.title.semiBold,
        ),
        content: Text(
          'It will be gone from the list.',
          style: theme.typography.label.regular,
        ),
        actions: [
          AppTextButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          AppFilledButton(
            label: 'Delete',
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final deleted = await viewModel.deletePost();

    if (deleted && context.mounted) {
      Navigator.of(context).pop();
    }
  }
}
