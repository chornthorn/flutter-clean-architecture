import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';

import '../../../../core/design_system/app_theme.g.dart';
import '../../../../core/design_system/components/app_buttons.dart';
import '../../../../core/design_system/components/app_card.dart';
import '../../../../core/design_system/components/app_text_field.dart';
import '../../../../core/presentation/action_result.dart';
import '../../../../core/presentation/form/app_form_scope.dart';
import '../forms/post_form_field.dart';

export '../forms/post_form_field.dart';

/// Modal dialog for creating or editing a post.
///
/// Driven entirely by a ViewModel-owned [AppFormController].
class PostFormDialog extends StatelessWidget {
  const PostFormDialog({
    super.key,
    required this.heading,
    required this.submitLabel,
    required this.formController,
    required this.onSubmit,
  });

  final String heading;
  final String submitLabel;
  final AppFormController formController;
  final Future<ActionResult> Function() onSubmit;

  Future<void> _submit(BuildContext context) async {
    final result = await formController.submit(onSubmit);
    if (result is ActionSuccess && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return AppFormScope(
      controller: formController,
      options: const AppFormOptions(
        autovalidateMode: AutovalidateMode.onUserInteraction,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    heading,
                    style: theme.typography.title.semiBold.copyWith(
                      color: theme.colors.foreground.primary,
                    ),
                  ),
                  SignalBuilder(
                    builder: (context) {
                      final error = formController.errorMessage.value;
                      if (error == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: _buildErrorBanner(context, error),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    fieldKey: const FormFieldKey(PostFormField.title),
                    label: 'Title',
                    hintText: 'Give your post a title',
                    validator: (value) {
                      final trimmed = (value ?? '').trim();
                      if (trimmed.isEmpty) return 'Title cannot be empty.';
                      if (trimmed.length < 5) {
                        return 'Title must be at least 5 characters.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  const AppTextField(
                    fieldKey: FormFieldKey(PostFormField.body),
                    label: 'Body',
                    hintText: 'Write something...',
                    maxLines: 4,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SignalBuilder(
                        builder: (context) {
                          final isSubmitting = formController.isSubmitting.value;
                          return AppOutlinedButton(
                            label: 'Cancel',
                            onPressed: isSubmitting
                                ? null
                                : () => Navigator.of(context).pop(),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      SignalBuilder(
                        builder: (context) {
                          final isSubmitting = formController.isSubmitting.value;
                          final title = formController
                              .signal(const FormFieldKey(PostFormField.title))
                              .value;
                          return AppFilledButton(
                            label: submitLabel,
                            isEnabled: !isSubmitting && title.trim().isNotEmpty,
                            onPressed: () => _submit(context),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorBanner(BuildContext context, String message) {
    final theme = context.theme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: theme.sizes.padding.sm,
        vertical: theme.sizes.padding.sm,
      ),
      decoration: BoxDecoration(
        color: theme.colors.feedback.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(theme.sizes.radius.sm),
        border: Border.all(
          color: theme.colors.feedback.danger.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: theme.sizes.icon.sm,
            color: theme.colors.feedback.danger,
          ),
          SizedBox(width: theme.sizes.spacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.typography.label.regular.copyWith(
                color: theme.colors.feedback.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
