import 'package:flutter/material.dart';

import '../../../api/api.dart';
import '../../../ui/ui.dart';
import '../staff_format.dart';

/// A student's risk flags as warning chips.
class RiskFlagChips extends StatelessWidget {
  const RiskFlagChips({super.key, required this.flags});

  final List<RiskFlag> flags;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final f in flags)
          Chip(
            avatar: Icon(Icons.flag_outlined, color: scheme.error, size: 18),
            label: Text(riskFlagLabel(f)),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}
