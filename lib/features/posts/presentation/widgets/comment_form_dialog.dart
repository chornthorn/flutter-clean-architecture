import 'package:flutter/material.dart';
import 'package:flutter_x/features/posts/presentation/view_models/post_view_model.dart';
import 'package:flutter_x/provider.dart';
import 'package:signals/signals_flutter.dart';

import '../../../../core/design_system/app_theme.g.dart';
import '../../../../core/design_system/components/app_buttons.dart';
import '../../../../core/design_system/components/app_card.dart';
import '../../../../core/design_system/components/app_form_error_banner.dart';
import '../../../../core/design_system/components/app_text_field.dart';
import '../../../../core/presentation/action_result.dart';
import '../../../../core/presentation/form/app_form_scope.dart';
import '../forms/comment_form_field.dart';

export '../forms/comment_form_field.dart';

/// Modal dialog for adding a comment to a post.
///
/// Driven entirely by a ViewModel-owned [AppFormController].
class CommentFormDialog extends StatelessWidget {
  const CommentFormDialog({
    super.key,
    required this.formController,
    required this.onSubmit,
  });

  final AppFormController formController;
  final Future<ActionResult> Function() onSubmit;

  Future<void> _submit(BuildContext context) async {
    final result = await formController.submit(onSubmit);
    if (result is ActionSuccess && context.mounted) {
      Navigator.of(context).pop();

     // final model =  getIt.get<PostViewModel>();
     // print(model);
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
                    'Add comment',
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
                        child: AppFormErrorBanner(message: error),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    fieldKey: const FormFieldKey(CommentFormField.name),
                    label: 'Name',
                    hintText: 'Who is writing?',
                    validator: (value) {
                      final trimmed = (value ?? '').trim();
                      if (trimmed.isEmpty) return 'A comment needs a name.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    fieldKey: const FormFieldKey(CommentFormField.email),
                    label: 'Email',
                    hintText: 'you@example.com',
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      final trimmed = (value ?? '').trim();
                      if (trimmed.isEmpty) {
                        return 'A comment needs an email address.';
                      }
                      if (!trimmed.contains('@')) {
                        return 'Enter an email address like ada@example.com.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    fieldKey: const FormFieldKey(CommentFormField.body),
                    label: 'Body',
                    hintText: 'Write something...',
                    maxLines: 3,
                    validator: (value) {
                      final trimmed = (value ?? '').trim();
                      if (trimmed.isEmpty) return 'A comment needs a body.';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SignalBuilder(
                        builder: (context) {
                          final isSubmitting =
                              formController.isSubmitting.value;
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
                          final isSubmitting =
                              formController.isSubmitting.value;
                          return AppFilledButton(
                            label: 'Add',
                            isEnabled: formController.isValid.value,
                            isLoading: isSubmitting,
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
}
