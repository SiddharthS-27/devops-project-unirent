import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api.dart';
import '../../app/error_messages.dart';
import '../../app/routes.dart';
import '../../ui/ui.dart';
import 'booking_providers.dart';
import 'widgets/booking_tile.dart';

const _groups = [
  (BookingGroup.pending, 'Pending'),
  (BookingGroup.upcoming, 'Upcoming'),
  (BookingGroup.active, 'Active'),
  (BookingGroup.past, 'Past'),
  (BookingGroup.cancelled, 'Cancelled'),
];

/// The Bookings tab: things you're renting or buying, or (as an owner)
/// lending or selling, by stage.
class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  TradeRole _role = TradeRole.renter;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _groups.length,
      initialIndex: 2, // Active
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bookings'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final (_, label) in _groups) Tab(text: label)],
          ),
        ),
        // The role switch sits in the body so it can grow with large text.
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.md,
                AppSpacing.screen,
                0,
              ),
              child: SegmentedButton<TradeRole>(
                segments: const [
                  ButtonSegment(
                    value: TradeRole.renter,
                    label: Text('Renting & buying'),
                  ),
                  ButtonSegment(
                    value: TradeRole.owner,
                    label: Text('Lending & selling'),
                  ),
                ],
                selected: {_role},
                onSelectionChanged: (s) => setState(() => _role = s.single),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  for (final (group, _) in _groups)
                    _BookingList(role: _role, group: group),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingList extends ConsumerStatefulWidget {
  const _BookingList({required this.role, required this.group});

  final TradeRole role;
  final BookingGroup group;

  @override
  ConsumerState<_BookingList> createState() => _BookingListState();
}

class _BookingListState extends ConsumerState<_BookingList> {
  /// Pages after the first, loaded with "Show more".
  final _more = <BookingSummary>[];
  String? _cursor;
  bool _loadingMore = false;

  @override
  void didUpdateWidget(_BookingList old) {
    super.didUpdateWidget(old);
    if (old.role != widget.role) {
      _more.clear();
      _cursor = null;
    }
  }

  Future<void> _loadMore(String cursor) async {
    setState(() => _loadingMore = true);
    try {
      final page = await ref
          .read(apiProvider)
          .bookings
          .listBookings(role: widget.role, group: widget.group, cursor: cursor);
      if (!mounted) return;
      setState(() {
        _more.addAll(page.items);
        _cursor = page.nextCursor ?? '';
      });
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyMessage(error))));
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = (widget.role, widget.group);
    return ref
        .watch(myBookingsProvider(key))
        .when(
          loading: () => const LoadingState(),
          error: (error, _) => ErrorState(
            message: friendlyMessage(error),
            onRetry: () => ref.invalidate(myBookingsProvider(key)),
          ),
          data: (first) {
            final items = [...first.items, ..._more];
            // '' marks "no more pages" once a later page said so.
            final next = _cursor ?? first.nextCursor;
            if (items.isEmpty) {
              return EmptyState(
                icon: Icons.event_note_outlined,
                title: 'Nothing here',
                message: widget.role == TradeRole.renter
                    ? 'Items you rent or buy show up here.'
                    : 'Bookings on your listings show up here.',
              );
            }
            return RefreshIndicator(
              onRefresh: () {
                _more.clear();
                _cursor = null;
                return ref.refresh(myBookingsProvider(key).future);
              },
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.screen),
                children: [
                  for (final b in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: BookingTile(
                        booking: b,
                        onTap: () => context.push(Routes.booking(b.id)),
                      ),
                    ),
                  if (next != null && next.isNotEmpty)
                    Center(
                      child: TextButton(
                        onPressed: _loadingMore ? null : () => _loadMore(next),
                        child: const Text('Show more'),
                      ),
                    ),
                ],
              ),
            );
          },
        );
  }
}
