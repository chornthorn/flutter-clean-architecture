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
//
// The page requires the id rather than reading it back off the view model, so
// which post this screen shows is visible from its constructor.
class PostDetailView extends StatelessWidget {
  const PostDetailView({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context) {
    // Read once, subscribe never: what changes lives in the view model's
    // signals, and `SignalBuilder` is what rebuilds this page off the ones read
    // below. It spans the whole screen because the app bar and the body answer
    // to the same state.
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
    // Nothing to edit or delete until there is a post on screen. The state's
    // value is null while the read is in flight, after a failure, and for an id
    // that resolved to nothing.
    final post = state.value;
    if (post == null) return const [];

    // One write at a time from this screen, and each use case says whether it is
    // the one in flight.
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

    // `AsyncDataReloading` and `AsyncDataRefreshing` implement `AsyncLoading`, so
    // the arms that carry a value or a failure have to come before the loading
    // one — matching the loading arm first would swallow them.
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
      // A failure and a missing id both leave no post; only one is an error,
      // and only one of them is worth asking the far side again.
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
