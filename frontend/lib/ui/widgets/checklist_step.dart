import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';

enum ChecklistStepState { locked, available, done }

/// One row of a step-by-step checklist (e.g. pickup or return).
///
/// Locked steps are dimmed and show a lock; available steps show the action
/// button; done steps show a check mark.
class ChecklistStep extends StatelessWidget {
  const ChecklistStep({
    super.key,
    required this.title,
    required this.state,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? subtitle;
  final ChecklistStepState state;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLocked = state == ChecklistStepState.locked;

    final (IconData icon, Color iconColor, String stateLabel) = switch (state) {
      ChecklistStepState.locked => (
        Icons.lock_outline,
        scheme.outline,
        'locked',
      ),
      ChecklistStepState.available => (
        Icons.radio_button_unchecked,
        AppSurfaces.of(context).accent,
        'to do',
      ),
      ChecklistStepState.done => (
        Icons.check_circle,
        StatusColors.of(context).success,
        'done',
      ),
    };

    final actionLabel = this.actionLabel;
    final action = state == ChecklistStepState.available && actionLabel != null
        ? FilledButton(
            onPressed: onAction,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, AppSizes.minTouchTarget),
            ),
            child: Text(actionLabel),
          )
        : null;
    // With large text the button goes under the step so neither is cramped.
    final stacked = MediaQuery.textScalerOf(context).scale(10) > 13;

    final step = MergeSemantics(
      child: Row(
        children: [
          Icon(icon, color: iconColor, semanticLabel: stateLabel),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: isLocked
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: action == null
          ? step
          : stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                step,
                const SizedBox(height: AppSpacing.sm),
                Align(alignment: AlignmentDirectional.centerEnd, child: action),
              ],
            )
          : Row(
              children: [
                Expanded(child: step),
                const SizedBox(width: AppSpacing.sm),
                action,
              ],
            ),
    );
  }
}
