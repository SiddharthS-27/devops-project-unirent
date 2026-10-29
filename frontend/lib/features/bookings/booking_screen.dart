import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../ui/ui.dart';

/// A single booking, shared by renter (Bookings tab) and owner (Listings tab).
class BookingScreen extends StatelessWidget {
  const BookingScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking'),
        // Opened from a deep link there is nothing to pop back to.
        leading: context.canPop()
            ? null
            : BackButton(onPressed: () => context.go(Routes.bookings)),
      ),
      body: EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Booking $bookingId',
        message: 'Status, checklist and actions will appear here.',
      ),
    );
  }
}
