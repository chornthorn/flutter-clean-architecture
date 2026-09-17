import 'package:flutter/material.dart';
import 'package:kaisel/kaisel.dart';
import 'package:provider/provider.dart';
import 'package:signals/signals_flutter.dart';

import '../../../../app/app_route.dart';
import '../../../../core/design_system/components/app_toast.dart';
import '../../../../core/presentation/action_result.dart';
import '../../domain/entities/post.dart';
import '../../posts_module.dart';
import '../view_models/post_view_model.dart';
import '../widgets/post_form_dialog.dart';
import '../widgets/post_tile.dart';

/// The posts list screen.
///
/// Dispatches queries through [PostViewModel]. All mutation forms and
/// transitions pass through here.
class PostsHomeView extends StatelessWidget {
  const PostsHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PostViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Posts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New post',
            onPressed: () => _compose(context, viewModel),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Exit posts',
            onPressed: () => context.router<AppRoute>().pop(),
          ),
        ],
      ),
      body: SignalBuilder(
        builder: (context) {
          final state = viewModel.posts.value;
          return state.map(
            data: (posts) => _buildList(context, viewModel, posts),
            error: (error, _) => _buildError(context, viewModel, error),
            loading: () => const Center(child: CircularProgressIndicator()),
            reloading: () => const Center(child: CircularProgressIndicator()),
          );
        },
      ),
    );
  }

  Widget _buildError(
    BuildContext context,
    PostViewModel viewModel,
    Object error,
  ) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Could not load posts.'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: viewModel.load,
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    PostViewModel viewModel,
    List<Post> posts,
  ) {
    if (posts.isEmpty) {
      return const Center(child: Text('No posts yet.'));
    }

    // `RefreshIndicator` holds the pull gesture; `viewModel.load()` re-runs the query.
    return RefreshIndicator(
      onRefresh: viewModel.load,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: posts.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final post = posts[index];
          return PostTile(
            post: post,
            onTap: () => _openDetail(context, viewModel, post.id),
          );
        },
      ),
    );
  }

  // Uses Kaisel's pushForResult so the page is notified when the child route
  // pops: a post edited on the detail screen must show the new title here too.
  Future<void> _openDetail(
    BuildContext context,
    PostViewModel viewModel,
    int id,
  ) async {
    await context.pushForResult<void>(PostDetail(id));

    // The feature can be left with the detail still up, which takes this page
    // with it.
    if (!context.mounted) return;

    await viewModel.load();
  }

  Future<void> _compose(BuildContext context, PostViewModel viewModel) {
    viewModel.prepareCreate();
    return showDialog<void>(
      context: context,
      builder: (_) => PostFormDialog(
        heading: 'New post',
        submitLabel: 'Create',
        formController: viewModel.form,
        onSubmit: () async {
          final result = await viewModel.createPost();
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
}
