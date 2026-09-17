import 'package:flutter/material.dart';
import 'package:kaisel/kaisel.dart';
import 'package:provider/provider.dart';
import 'package:signals/signals_flutter.dart';

import '../../../../app/app_route.dart';
import '../../../../core/design_system/components/app_notice.dart';
import '../../../../core/design_system/components/app_scaffold.dart';
import '../../../../core/design_system/components/app_toast.dart';
import '../../../../core/presentation/action_result.dart';
import '../../domain/entities/post.dart';
import '../../posts_module.dart';
import '../view_models/posts_home_view_model.dart';
import '../widgets/post_form_dialog.dart';
import '../widgets/post_tile.dart';

// Reads the list from `PostsHomeViewModel` through signals: rebuilds when a
// signal emits, not when the view model says so.
class PostsHomeView extends StatelessWidget {
  const PostsHomeView({super.key});

  @override
  Widget build(BuildContext context) {
    // Read once, rebuild through the SignalBuilder below. Subscribing to the
    // provider would rebuild the page on nothing, since the view model does not notify.
    final viewModel = context.read<PostsHomeViewModel>();

    return SignalBuilder(
      builder: (context) => AppScaffold(
        title: const Text('Posts'),
        actions: [
          IconButton(
            onPressed: () => _compose(context, viewModel),
            icon: const Icon(Icons.add),
            tooltip: 'New post',
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
    PostsHomeViewModel viewModel,
    AsyncState<List<Post>> state,
  ) {
    // `AsyncData*` first: the reloading and refreshing states implement `AsyncLoading`.
    return switch (state) {
      AsyncData<List<Post>>(:final value) => _buildList(context, viewModel, value),
      AsyncError<List<Post>>() => AppNotice(
        icon: Icons.cloud_off_outlined,
        message: 'Could not load posts.',
        action: TextButton(
          onPressed: viewModel.load,
          child: const Text('Try again'),
        ),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }

  Widget _buildList(
    BuildContext context,
    PostsHomeViewModel viewModel,
    List<Post> posts,
  ) {
    if (posts.isEmpty) {
      return const AppNotice(
        icon: Icons.inbox_outlined,
        message: 'No posts yet.',
      );
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
    PostsHomeViewModel viewModel,
    int id,
  ) async {
    await context.pushForResult<void>(PostDetail(id));

    // The feature can be left with the detail still up, which takes this page
    // with it.
    if (!context.mounted) return;

    await viewModel.load();
  }

  Future<void> _compose(BuildContext context, PostsHomeViewModel viewModel) {
    viewModel.form.clear();
    return showDialog<void>(
      context: context,
      builder: (_) => PostFormDialog(
        heading: 'New post',
        submitLabel: 'Create',
        formController: viewModel.form,
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
}
