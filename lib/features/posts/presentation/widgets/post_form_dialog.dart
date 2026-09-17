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
class PostFormDialog extends StatefulWidget {
  const PostFormDialog({
    super.key,
    required this.heading,
    required this.submitLabel,
    required this.formController,
    required this.onSubmit,
    this.initialTitle,
    this.initialBody,
  });

  final String heading;
  final String submitLabel;
  final AppFormController formController;
  final Future<ActionResult> Function() onSubmit;
  final String? initialTitle;
  final String? initialBody;

  @override
  State<PostFormDialog> createState() => _PostFormDialogState();
}

class _PostFormDialogState extends State<PostFormDialog> {
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final values = <dynamic, String>{};
    if (widget.initialTitle != null && widget.initialTitle!.isNotEmpty) {
      values[PostFormField.title] = widget.initialTitle!;
    }
    if (widget.initialBody != null && widget.initialBody!.isNotEmpty) {
      values[PostFormField.body] = widget.initialBody!;
    }
    if (values.isNotEmpty) {
      widget.formController.setValues(values);
    }
  }

  Future<void> _submit() async {
    if (!widget.formController.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final result = await widget.onSubmit();

    if (result is ActionFailure) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = result.fieldErrors.isEmpty ? result.message : null;
        });
      }
      return;
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return AppFormScope(
      controller: widget.formController,
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
                    widget.heading,
                    style: theme.typography.title.semiBold.copyWith(
                      color: theme.colors.foreground.primary,
                    ),
                  ),
                  if (_errorMessage case final message?) ...[
                    const SizedBox(height: 12),
                    _buildErrorBanner(context, message),
                  ],
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
                      AppOutlinedButton(
                        label: 'Cancel',
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      SignalBuilder(
                        builder: (context) {
                          final title = widget.formController
                              .signal(const FormFieldKey(PostFormField.title))
                              .value;
                          return AppFilledButton(
                            label: widget.submitLabel,
                            isLoading: _isSubmitting,
                            onPressed: title.trim().isEmpty || _isSubmitting
                                ? null
                                : _submit,
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colors.state.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.colors.state.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: theme.colors.state.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.typography.caption.regular.copyWith(
                color: theme.colors.state.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
