import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';
import '../../app/error_messages.dart';
import '../../ui/ui.dart';
import '../bookings/booking_format.dart';
import '../bookings/booking_providers.dart';
import '../listings/listing_providers.dart';
import 'widgets/profile_avatar.dart';
import 'widgets/profile_reviews.dart';
import 'widgets/trust_section.dart';

/// Someone else's profile, as the server lets you see it.
class PublicProfileScreen extends ConsumerWidget {
  const PublicProfileScreen({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileViewProvider(accountId));
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profile.when(
        loading: () => const LoadingState(),
        error: (error, _) => ErrorState(
          message: friendlyMessage(error),
          onRetry: () => ref.invalidate(profileViewProvider(accountId)),
        ),
        data: (p) => _ProfileView(profile: p),
      ),
    );
  }
}

class _ProfileView extends ConsumerWidget {
  const _ProfileView({required this.profile});

  final ProfileView profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final phone = profile.phone;
    final residence = switch (profile) {
      ProfileCounterparty(:final residence) => residenceLabel(residence),
      ProfileStaff(:final residence) => residenceLabel(residence),
      _ => null,
    };
    final isOwn = profile is ProfileOwn;
    const gap = SizedBox(height: AppSpacing.xl);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.screen),
      children: [
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
                  Text(profile.fullName, style: theme.textTheme.titleLarge),
                  Text(
                    '${profile.department} · Year ${profile.year}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (residence != null)
                    Text(residence, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
        if (phone != null && !isOwn) ...[
          const SizedBox(height: AppSpacing.lg),
          AppButton.secondary(
            label: 'Call ${profile.fullName.split(' ').first}',
            icon: Icons.call_outlined,
            onPressed: () => ref.read(phoneCallerProvider)(phone),
          ),
        ],
        gap,
        TrustSection(profile: profile),
        gap,
        ProfileReviews(accountId: profile.accountId),
      ],
    );
  }
}
