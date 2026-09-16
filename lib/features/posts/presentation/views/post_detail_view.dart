import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/design_system/app_theme.g.dart';
import '../view_models/post_detail_view_model.dart';

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
      appBar: AppBar(title: Text('Post $id')),
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
}
