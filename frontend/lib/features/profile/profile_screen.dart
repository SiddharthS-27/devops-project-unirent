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
                    radius: 32,
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
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          '${profile.department} · Year ${profile.year}',
                          style: theme.textTheme.bodyMedium,
                        ),
                        Text(
                          profile.email,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              gap,
              TrustSection(profile: profile),
              gap,
            ],
            _LinkGroup(
              rows: [
                _LinkRow(
                  icon: Icons.edit_outlined,
                  label: 'Edit profile',
                  onTap: profile == null
                      ? null
                      : () => context.push(Routes.editProfile),
                ),
                _LinkRow(
                  icon: Icons.inventory_2_outlined,
                  label: 'Items you own',
                  onTap: () => context.push(Routes.ownedItems),
                ),
                _LinkRow(
                  icon: Icons.receipt_long_outlined,
                  label: 'Payment history',
                  onTap: () => context.push(Routes.paymentHistory),
                ),
                _LinkRow(
                  icon: Icons.account_balance_outlined,
                  label: 'Payout account',
                  onTap: () => context.push(Routes.payoutAccount),
                ),
                _LinkRow(
                  icon: Icons.help_outline,
                  label: 'Help & support',
                  onTap: () => context.push(Routes.help),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _LinkGroup(
              rows: [
                _LinkRow(
                  icon: Icons.logout,
                  label: 'Sign out',
                  busy: _signingOut,
                  chevron: false,
                  onTap: _signingOut ? null : _signOut,
                ),
              ],
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

/// One card of account links, split by rules.
class _LinkGroup extends StatelessWidget {
  const _LinkGroup({required this.rows});

  final List<_LinkRow> rows;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      semanticContainer: false,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(indent: AppSpacing.screen),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.busy = false,
    this.chevron = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool busy;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      enabled: onTap != null,
      leading: Icon(icon, size: AppSizes.iconMd - 2),
      title: Text(label),
      trailing: busy
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                semanticsLabel: 'Loading',
              ),
            )
          : chevron
          ? Icon(
              Icons.chevron_right,
              size: AppSizes.iconMd - 2,
              color: scheme.onSurfaceVariant,
            )
          : null,
      onTap: onTap,
    );
  }
}
