import 'package:flutter/material.dart';

import '../theme.dart';
import '../tokens.dart';

enum TimelineStepState { done, current, upcoming }

class TimelineStep {
  const TimelineStep({required this.title, required this.state, this.subtitle});

  final String title;
  final String? subtitle;
  final TimelineStepState state;
}

/// Vertical list of steps with connecting lines, e.g. a booking's progress.
class StatusTimeline extends StatelessWidget {
  const StatusTimeline({super.key, required this.steps});

  final List<TimelineStep> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < steps.length; i++)
          _TimelineRow(step: steps[i], isLast: i == steps.length - 1),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.step, required this.isLast});

  final TimelineStep step;
  final bool isLast;

  static const double _indicatorSize = 24;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = AppSurfaces.of(context).accent;
    final isUpcoming = step.state == TimelineStepState.upcoming;

    final stateLabel = switch (step.state) {
      TimelineStepState.done => 'completed',
      TimelineStepState.current => 'in progress',
      TimelineStepState.upcoming => 'upcoming',
    };

    final indicator = switch (step.state) {
      TimelineStepState.done => Container(
        decoration: BoxDecoration(
          color: scheme.onSurface,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.check, size: AppSizes.iconXs, color: scheme.surface),
      ),
      TimelineStepState.current => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: accent, width: 2),
        ),
        padding: const EdgeInsets.all(5),
        child: DecoratedBox(
          decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
        ),
      ),
      TimelineStepState.upcoming => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: scheme.outline, width: 2),
        ),
      ),
    };

    return MergeSemantics(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: _indicatorSize,
              child: Column(
                children: [
                  SizedBox.square(dimension: _indicatorSize, child: indicator),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(
                          vertical: AppSpacing.xs,
                        ),
                        color: step.state == TimelineStepState.done
                            ? scheme.onSurface
                            : scheme.outlineVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  top: AppSpacing.xxs,
                  bottom: isLast ? 0 : AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      value: stateLabel,
                      child: Text(
                        step.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: isUpcoming
                              ? FontWeight.w500
                              : FontWeight.w600,
                          color: isUpcoming
                              ? scheme.onSurfaceVariant
                              : scheme.onSurface,
                        ),
                      ),
                    ),
                    if (step.subtitle != null)
                      Text(
                        step.subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
