import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/design_system/app_theme.g.dart';
import '../view_models/post_detail_view_model.dart';
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

    return Scaffold(
      appBar: AppBar(
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
      ),
      body: _buildBody(context, viewModel),
    );
  }

  Widget _buildBody(BuildContext context, PostDetailViewModel viewModel) {
    if (viewModel.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final post = viewModel.post;
    if (post == null) {
      // A failure and a missing id both leave no post; only one is an error.
      return Center(
        child: Text(
          viewModel.error == null ? 'Post not found.' : 'Could not load post.',
        ),
      );
    }

    final padding = context.theme.sizes.padding.md;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(post.title, style: Theme.of(context).textTheme.titleLarge),
          SizedBox(height: context.theme.sizes.spacing.md),
          Text(post.body),
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
    // Deleting is not undoable, so it asks first.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this post?'),
        content: const Text('It will be gone from the list.'),
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

    final deleted = await viewModel.deletePost();

    // There is nothing left on this screen, so it leaves the stack.
    if (deleted && context.mounted) {
      Navigator.of(context).pop();
    }
  }
}
