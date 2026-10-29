import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../app/session.dart';
import '../../ui/ui.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    // Sign-out always succeeds locally; the router then leaves this screen.
    await ref.read(sessionProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(sessionProvider).me;
    final profile = me?.profile;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: EmptyState(
        icon: Icons.account_circle_outlined,
        title: profile?.fullName ?? 'Your profile',
        message: me?.account.email,
        action: Column(
          children: [
            if (profile != null) ...[
              TrustBadge(score: profile.renter.score),
              const SizedBox(height: AppSpacing.lg),
            ],
            AppButton.secondary(
              label: 'Help & support',
              icon: Icons.help_outline,
              onPressed: () => context.push(Routes.help),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton.secondary(
              label: 'Sign out',
              icon: Icons.logout,
              isLoading: _signingOut,
              onPressed: _signOut,
            ),
          ],
        ),
      ),
    );
  }
}
