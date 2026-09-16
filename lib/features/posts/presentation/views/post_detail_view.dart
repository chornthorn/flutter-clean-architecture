import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/design_system/app_theme.g.dart';
import '../../../../core/design_system/components/app_buttons.dart';
import '../../../../core/design_system/components/app_card.dart';
import '../../../../core/design_system/components/app_notice.dart';
import '../../../../core/design_system/components/app_scaffold.dart';
import '../view_models/post_detail_view_model.dart';
import '../widgets/post_byline.dart';
import '../widgets/post_form_dialog.dart';

// One post, looked up by the id carried on `PostDetail`.
//
// The page requires the id rather than reading it back off the view model, so
// which post this screen shows is visible from its constructor.
class PostDetailView extends StatelessWidget {
  const PostDetailView({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PostDetailViewModel>();

    return AppScaffold(
      title: Text('Post $id'),
      actions: [
        // Nothing to edit or delete until there is a post on screen.
        if (viewModel.post != null) ...[
          IconButton(
            onPressed: () => _edit(context, viewModel),
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit post',
          ),
          IconButton(
            onPressed: () => _delete(context, viewModel),
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete post',
          ),
        ],
      ],
      body: _buildBody(context, viewModel),
    );
  }

  Widget _buildBody(BuildContext context, PostDetailViewModel viewModel) {
    final theme = context.theme;

    if (viewModel.isLoading) {
      return Center(
        child: CircularProgressIndicator(color: theme.colors.brand.primary),
      );
    }

    final post = viewModel.post;
    if (post == null) {
      // A failure and a missing id both leave no post; only one is an error,
      // and only one of them is worth asking the far side again.
      if (viewModel.error != null) {
        return AppNotice(
          icon: Icons.cloud_off_outlined,
          message: 'Could not load post.',
          isFailure: true,
          action: AppFilledButton(
            label: 'Try again',
            onPressed: () => viewModel.load(id),
          ),
        );
      }

      return const AppNotice(
        icon: Icons.search_off_outlined,
        message: 'Post not found.',
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(theme.sizes.padding.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The headline belongs to the page, so it takes the display step and
          // sits on the canvas; the body below it is content, so it takes a
          // card, the way a row does in the list.
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
  ) async {
    final post = viewModel.post;
    if (post == null) return;

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
        // The icon says the action is destructive. The button does not carry
        // that colour: the danger token is a fill, and its inverse pair sits
        // under the contrast a label needs.
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

    // There is nothing left on this screen, so it leaves the stack.
    if (deleted && context.mounted) {
      Navigator.of(context).pop();
    }
  }
}
