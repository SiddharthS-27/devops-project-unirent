import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api.dart';
import '../../ui/ui.dart' show serverClockOffset;

/// First page of the user's bookings for a side and group.
final myBookingsProvider = FutureProvider.autoDispose
    .family<BookingSummaryPage, (TradeRole, BookingGroup)>(
      (ref, key) => ref
          .watch(apiProvider)
          .bookings
          .listBookings(role: key.$1, group: key.$2),
    );

/// Pending requests on the user's listings (all, or one listing's).
final incomingRequestsProvider = FutureProvider.autoDispose
    .family<List<BookingSummary>, String?>((ref, listingId) async {
      final page = await ref
          .watch(apiProvider)
          .bookings
          .listBookings(
            role: TradeRole.owner,
            group: BookingGroup.pending,
            listingId: listingId,
            limit: 50,
          );
      return page.items;
    });

/// Someone's profile as the signed-in user may see it.
final profileViewProvider = FutureProvider.autoDispose
    .family<ProfileView, String>(
      (ref, accountId) => ref.watch(apiProvider).profiles.getProfile(accountId),
    );

final bookingProvider = FutureProvider.autoDispose.family<BookingOut, String>((
  ref,
  id,
) async {
  final booking = await ref.watch(apiProvider).bookings.getBooking(id);
  ref.read(serverClockProvider).sync(booking.serverNow);
  return booking;
});

/// Device-to-server clock offset, refreshed from each booking's
/// `server_now`; countdowns add it to the device clock.
class ServerClock {
  Duration offset = Duration.zero;

  void sync(DateTime serverNow) => offset = serverClockOffset(serverNow);
}

final serverClockProvider = Provider<ServerClock>((ref) => ServerClock());
