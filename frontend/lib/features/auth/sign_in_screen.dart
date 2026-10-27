import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/session.dart';
import '../../ui/ui.dart';

class SignInScreen extends ConsumerWidget {
  const SignInScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.read(sessionProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: EmptyState(
        icon: Icons.school_outlined,
        title: 'Welcome to UniRent',
        message: 'Rent and resell with students on your campus.',
        action: Column(
          children: [
            AppButton(
              label: 'Continue with college account',
              icon: Icons.login,
              // Placeholder until Google sign-in is wired up.
              onPressed: () => session.set(SessionStatus.onboarding),
            ),
            if (kDebugMode) _DebugRoleSwitcher(onSelected: session.set),
          ],
        ),
      ),
    );
  }
}

/// Debug builds only: jump straight into the app as a given role.
class _DebugRoleSwitcher extends StatelessWidget {
  const _DebugRoleSwitcher({required this.onSelected});

  final ValueChanged<SessionStatus> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xl),
      child: Column(
        children: [
          Text(
            'Debug: enter as',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            alignment: WrapAlignment.center,
            children: [
              for (final role in const [
                SessionStatus.student,
                SessionStatus.moderator,
                SessionStatus.admin,
              ])
                OutlinedButton(
                  onPressed: () => onSelected(role),
                  child: Text(role.name),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
