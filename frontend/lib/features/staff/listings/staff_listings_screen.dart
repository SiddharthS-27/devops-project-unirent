import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/api.dart';
import '../../../app/error_messages.dart';
import '../../../ui/ui.dart';
import '../../listings/listing_format.dart';
import '../../listings/widgets/listing_photo.dart';
import '../staff_format.dart';
import '../widgets/paged_list.dart';
import '../widgets/reason_dialog.dart';

/// All listings, newest first; remove one with a reason.
class StaffListingsScreen extends ConsumerStatefulWidget {
  const StaffListingsScreen({super.key});

  @override
  ConsumerState<StaffListingsScreen> createState() =>
      _StaffListingsScreenState();
}

class _StaffListingsScreenState extends ConsumerState<StaffListingsScreen> {
  final _search = TextEditingController();
  String _q = '';
  ListingStatus? _status;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _remove(ListingCard l, VoidCallback reload) async {
    final reason = await showReasonDialog(
      context,
      title: 'Remove “${l.title}”?',
      confirmLabel: 'Remove',
      message: 'It disappears from search and can’t be booked.',
    );
    if (reason == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(apiProvider)
          .staff
          .removeListing(l.id, ReasonIn(reason: reason));
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Listing removed.')));
      reload();
    } catch (error) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(friendlyMessage(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.watch(apiProvider);
    final theme = Theme.of(context);
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              0,
            ),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              maxLength: 100,
              onSubmitted: (_) => setState(() => _q = _search.text.trim()),
              decoration: InputDecoration(
                hintText: 'Search titles',
                counterText: '',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Search',
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => setState(() => _q = _search.text.trim()),
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Row(
              children: [
                for (final s in [
                  null,
                  ListingStatus.active,
                  ListingStatus.paused,
                  ListingStatus.sold,
                  ListingStatus.removed,
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: ChoiceChip(
                      label: Text(s == null ? 'All' : listingStatusLabel(s)),
                      selected: _status == s,
                      onSelected: (_) => setState(() => _status = s),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: PagedList<ListingCard>(
              queryKey: (_q, _status),
              load: (cursor) async {
                final page = await api.staff.listings(
                  q: _q.isEmpty ? null : _q,
                  status: _status,
                  cursor: cursor,
                );
                return (items: page.items, next: page.nextCursor);
              },
              itemBuilder: (context, l, reload) => ListTile(
                leading: SizedBox.square(
                  dimension: 48,
                  child: ListingPhoto(
                    url: l.photoUrl,
                    category: l.category,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
                title: Text(l.title),
                subtitle: Text(
                  '${l.owner.fullName} · ${categoryLabel(l.category)} · '
                  '${listingStatusLabel(l.status)}',
                ),
                trailing: l.status == ListingStatus.removed
                    ? null
                    : TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                        ),
                        onPressed: () => _remove(l, reload),
                        child: const Text('Remove'),
                      ),
              ),
              empty: const EmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'No listings found',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
