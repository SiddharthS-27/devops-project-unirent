import 'package:flutter/material.dart';

import '../../app/session.dart';
import '../../ui/ui.dart';

/// Shared frame for onboarding steps: title, progress and scrolling body.
class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.step,
    required this.title,
    required this.children,
  });

  final OnboardingStep step;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final index = step.index + 1;
    final total = OnboardingStep.values.length;
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: Semantics(
            label: 'Step $index of $total',
            child: LinearProgressIndicator(value: index / total, minHeight: 3),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: children,
        ),
      ),
    );
  }
}
