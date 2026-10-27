import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../ui/ui.dart';

/// Bookings the student made as a renter.
class BookingsScreen extends StatelessWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bookings')),
      body: EmptyState(
        icon: Icons.event_note_outlined,
        title: 'No bookings yet',
        message: 'Items you rent or buy will show up here.',
        action: AppButton.secondary(
          label: 'Open sample booking',
          onPressed: () => context.push(Routes.booking('sample')),
        ),
      ),
    );
  }
}
