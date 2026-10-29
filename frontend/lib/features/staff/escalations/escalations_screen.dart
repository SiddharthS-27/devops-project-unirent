import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api.dart';
import '../../../app/error_messages.dart';
import '../../../ui/ui.dart';
import '../../bookings/booking_format.dart';
import '../../listings/listing_providers.dart';
import '../staff_format.dart';
import '../staff_providers.dart';
import '../users/user_row_tile.dart';

enum _View { bookings, flagged }

/// Bookings that need someone to follow up in person, and students with
/// risk flags.
class EscalationsScreen extends ConsumerStatefulWidget {
  const EscalationsScreen({super.key});

  @override
  ConsumerState<EscalationsScreen> createState() => _EscalationsScreenState();
}

class _EscalationsScreenState extends ConsumerState<EscalationsScreen> {
  _View _view = _View.bookings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: SegmentedButton<_View>(
              segments: const [
                ButtonSegment(value: _View.bookings, label: Text('Bookings')),
                ButtonSegment(value: _View.flagged, label: Text('Risk flags')),
              ],
              selected: {_view},
              onSelectionChanged: (s) => setState(() => _view = s.single),
            ),
          ),
          Expanded(
            child: switch (_view) {
              _View.bookings => const _EscalatedBookings(),
              _View.flagged => const _FlaggedStudents(),
            },
          ),
        ],
      ),
    );
  }
}

class _EscalatedBookings extends ConsumerWidget {
  const _EscalatedBookings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final escalations = ref.watch(escalationsProvider);
    return escalations.when(
      loading: () => const LoadingState(),
      error: (error, _) => ErrorState(
        message: friendlyMessage(error),
        onRetry: () => ref.invalidate(escalationsProvider),
      ),
      data: (list) => RefreshIndicator(
        onRefresh: () => ref.refresh(escalationsProvider.future),
        child: list.isEmpty
            ? ListView(
                children: const [
                  EmptyState(
                    icon: Icons.report_problem_outlined,
                    title: 'Nothing to follow up',
                    message:
                        'Rentals overdue by an hour, owner escalations and '
                        'Proceeds stalled for a day show up here.',
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: list.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, i) => _EscalationCard(e: list[i]),
              ),
      ),
    );
  }
}

class _EscalationCard extends ConsumerWidget {
  const _EscalationCard({required this.e});

  final EscalationOut e;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final b = e.booking;
    final residence = residenceLabel(e.renterResidence);
    Widget person(String role, String name, String? phone, String? where) =>
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.person_outline),
          title: Text('$name ($role)'),
          subtitle: Text([?phone, ?where].join('\n')),
          isThreeLine: phone != null && where != null,
          trailing: phone == null
              ? null
              : IconButton(
                  tooltip: 'Call $name',
                  icon: const Icon(Icons.call_outlined),
                  onPressed: () => ref.read(phoneCallerProvider)(phone),
                ),
        );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_outlined,
                color: theme.colorScheme.error,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  escalationKindLabel(e.kind),
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          Text(
            'Since ${formatIstDateTime(e.since)}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(b.listingTitle, style: theme.textTheme.titleMedium),
          Text(
            '${bookingWhen(b.kind, b.startAt, b.endAt)} · '
            '${bookingStatusLabel(b.status)}',
            style: theme.textTheme.bodySmall,
          ),
          if (e.note case final note?) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Owner’s note: $note'),
          ],
          person('renter', e.renterName, e.renterPhone, residence),
          person('owner', e.ownerName, e.ownerPhone, null),
        ],
      ),
    );
  }
}

class _FlaggedStudents extends ConsumerWidget {
  const _FlaggedStudents();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flagged = ref.watch(flaggedUsersProvider);
    return flagged.when(
      loading: () => const LoadingState(),
      error: (error, _) => ErrorState(
        message: friendlyMessage(error),
        onRetry: () => ref.invalidate(flaggedUsersProvider),
      ),
      data: (page) => RefreshIndicator(
        onRefresh: () => ref.refresh(flaggedUsersProvider.future),
        child: page.items.isEmpty
            ? ListView(
                children: const [
                  EmptyState(
                    icon: Icons.flag_outlined,
                    title: 'No flagged students',
                    message:
                        'Repeated overdue returns, cancellations or disputes '
                        'in 30 days, or very low trust, flag a student.',
                  ),
                ],
              )
            : ListView.separated(
                itemCount: page.items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, i) => UserRowTile(
                  user: page.items[i],
                  onReturn: () => ref.invalidate(flaggedUsersProvider),
                ),
              ),
      ),
    );
  }
}
