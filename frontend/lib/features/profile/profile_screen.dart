import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../app/session.dart';
import '../../ui/ui.dart';
import 'widgets/profile_avatar.dart';
import 'widgets/profile_reviews.dart';
import 'widgets/trust_section.dart';

/// The Profile tab: your own profile, trust and reviews, and account links.
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
    final theme = Theme.of(context);
    final me = ref.watch(sessionProvider).me;
    final profile = me?.profile;
    const gap = SizedBox(height: AppSpacing.xl);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: RefreshIndicator(
        onRefresh: () => ref.read(sessionProvider.notifier).refreshMe(),
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screen),
          children: [
            if (profile != null) ...[
              Row(
                children: [
                  ProfileAvatar(
                    name: profile.fullName,
                    photoUrl: profile.photoUrl,
                    radius: 36,
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.fullName,
                          style: theme.textTheme.titleLarge,
                        ),
                        Text(
                          '${profile.department} · Year ${profile.year}',
                          style: theme.textTheme.bodyMedium,
                        ),
                        Text(profile.email, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              gap,
              TrustSection(profile: profile),
              gap,
            ],
            AppButton.secondary(
              label: 'Edit profile',
              icon: Icons.edit_outlined,
              onPressed: profile == null
                  ? null
                  : () => context.push(Routes.editProfile),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton.secondary(
              label: 'Payout account',
              icon: Icons.account_balance_outlined,
              onPressed: () => context.push(Routes.payoutAccount),
            ),
            const SizedBox(height: AppSpacing.sm),
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
            if (profile != null) ...[
              gap,
              ProfileReviews(accountId: profile.accountId),
            ],
          ],
        ),
      ),
    );
  }
}
