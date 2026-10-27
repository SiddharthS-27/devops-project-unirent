import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../app/session.dart';
import '../../ui/ui.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: EmptyState(
        icon: Icons.account_circle_outlined,
        title: 'Your profile',
        message: 'Trust score, reviews and settings will appear here.',
        action: Column(
          children: [
            AppButton.secondary(
              label: 'Help & support',
              icon: Icons.help_outline,
              onPressed: () => context.push(Routes.help),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton.secondary(
              label: 'Sign out',
              icon: Icons.logout,
              onPressed: ref.read(sessionProvider.notifier).signOut,
            ),
          ],
        ),
      ),
    );
  }
}
