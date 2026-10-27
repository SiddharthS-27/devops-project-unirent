import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/push_service.dart';
import '../../app/session.dart';
import '../../ui/ui.dart';
import 'onboarding_scaffold.dart';

/// Onboarding step 4: ask for notification permission.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _busy = false;

  void _finish() => ref.read(sessionProvider.notifier).finishOnboarding();

  Future<void> _enable() async {
    setState(() => _busy = true);
    try {
      await ref.read(pushServiceProvider).enable();
    } on Object catch (error) {
      // Not being able to register shouldn't block onboarding.
      debugPrint('Push registration failed: $error');
    }
    if (mounted) _finish();
  }

  @override
  Widget build(BuildContext context) {
    final available = ref.watch(pushServiceProvider).isAvailable;
    final theme = Theme.of(context);
    return OnboardingScaffold(
      step: OnboardingStep.notifications,
      title: 'Notifications',
      children: [
        Icon(
          Icons.notifications_active_outlined,
          size: AppSizes.iconLg,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (available) ...[
          Text(
            'Get notified when someone requests your item, when your booking '
            'is approved, and before a return is due.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Turn on notifications',
            isLoading: _busy,
            onPressed: _enable,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: _busy ? null : _finish,
            child: const Text('Not now'),
          ),
        ] else ...[
          Text(
            'Notifications aren’t configured in this build. You can still use '
            'UniRent; updates will show up inside the app.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(label: 'Continue', onPressed: _finish),
        ],
      ],
    );
  }
}
