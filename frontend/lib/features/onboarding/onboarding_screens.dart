import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../app/session.dart';
import '../../ui/ui.dart';

/// Shared layout for the onboarding steps.
class _OnboardingStep extends StatelessWidget {
  const _OnboardingStep({
    required this.step,
    required this.title,
    required this.message,
    required this.icon,
    required this.onContinue,
    this.continueLabel = 'Continue',
  });

  final int step;
  final String title;
  final String message;
  final IconData icon;
  final VoidCallback onContinue;
  final String continueLabel;

  static const _stepCount = 4;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: EmptyState(
        icon: icon,
        title: 'Step $step of $_stepCount',
        message: message,
        action: AppButton(label: continueLabel, onPressed: onContinue),
      ),
    );
  }
}

class OnboardingProfileScreen extends StatelessWidget {
  const OnboardingProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _OnboardingStep(
      step: 1,
      title: 'Your profile',
      message: 'Add your name, hostel and a photo.',
      icon: Icons.person_outline,
      onContinue: () => context.go(Routes.onboardingPhone),
    );
  }
}

class OnboardingPhoneScreen extends StatelessWidget {
  const OnboardingPhoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _OnboardingStep(
      step: 2,
      title: 'Phone number',
      message: 'Verify your phone so renters can reach you.',
      icon: Icons.phone_outlined,
      onContinue: () => context.go(Routes.onboardingTerms),
    );
  }
}

class OnboardingTermsScreen extends StatelessWidget {
  const OnboardingTermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _OnboardingStep(
      step: 3,
      title: 'Terms',
      message: 'Review and accept the UniRent community rules.',
      icon: Icons.description_outlined,
      continueLabel: 'Accept',
      onContinue: () => context.go(Routes.onboardingNotifications),
    );
  }
}

class OnboardingNotificationsScreen extends ConsumerWidget {
  const OnboardingNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _OnboardingStep(
      step: 4,
      title: 'Notifications',
      message: 'Get notified about requests, pickups and returns.',
      icon: Icons.notifications_outlined,
      continueLabel: 'Finish',
      onContinue: () =>
          ref.read(sessionProvider.notifier).set(SessionStatus.student),
    );
  }
}
