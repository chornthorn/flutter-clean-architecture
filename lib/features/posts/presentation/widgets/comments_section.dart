import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:signals/signals_flutter.dart';

import '../../../../core/design_system/app_theme.g.dart';
import '../../../../core/design_system/components/app_buttons.dart';
import '../../../../core/design_system/components/app_notice.dart';
import '../../../../core/design_system/components/app_toast.dart';
import '../../../../core/presentation/action_result.dart';
import '../../domain/entities/comment.dart';
import '../view_models/comment_view_model.dart';
import 'comment_form_dialog.dart';
import 'comment_tile.dart';

/// The thread under a post: what the catalog holds, plus the way to add one.
class CommentsSection extends StatelessWidget {
  const CommentsSection({super.key, required this.postId});

  final int postId;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<CommentViewModel>();
    final theme = context.theme;

    return SignalBuilder(
      builder: (context) {
        // Reading the write's own state is what stops a second one from starting.
        final isWriting = viewModel.create.value.isLoading;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Comments', style: theme.typography.title.semiBold),
                ),
                SizedBox(width: theme.sizes.spacing.sm),
                AppOutlinedButton(
                  label: 'Add comment',
                  onPressed: isWriting ? null : () => _add(context, viewModel),
                ),
              ],
            ),
            SizedBox(height: theme.sizes.spacing.sm),
            _buildThread(context, viewModel, viewModel.comments.value),
          ],
        );
      },
    );
  }

  Widget _buildThread(
    BuildContext context,
    CommentViewModel viewModel,
    AsyncState<List<Comment>> state,
  ) {
    final theme = context.theme;

    return switch (state) {
      AsyncData<List<Comment>>(:final value) when value.isEmpty =>
        const AppNotice(
          icon: Icons.chat_bubble_outline,
          message: 'No comments yet.',
        ),
      AsyncData<List<Comment>>(:final value) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < value.length; index++) ...[
            if (index > 0) SizedBox(height: theme.sizes.spacing.sm),
            CommentTile(comment: value[index]),
          ],
        ],
      ),
      AsyncError<List<Comment>>() => AppNotice(
        icon: Icons.cloud_off_outlined,
        message: 'Could not load comments.',
        isFailure: true,
        action: AppFilledButton(
          label: 'Try again',
          onPressed: () => viewModel.load(postId),
        ),
      ),
      AsyncLoading<List<Comment>>() => Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: theme.sizes.padding.lg),
          child: CircularProgressIndicator(color: theme.colors.brand.primary),
        ),
      ),
    };
  }

  Future<void> _add(BuildContext context, CommentViewModel viewModel) {
    viewModel.prepareCreate();
    return showDialog<void>(
      context: context,
      builder: (_) => CommentFormDialog(
        formController: viewModel.commentFormController,
        onSubmit: () async {
          final result = await viewModel.createComment(postId);
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
}
