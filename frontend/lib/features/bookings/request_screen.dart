import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// Placeholder for the booking request flow (next stage).
class RequestScreen extends StatelessWidget {
  const RequestScreen({super.key, required this.listingId});

  final String listingId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Request')),
      body: const EmptyState(
        icon: Icons.event_available_outlined,
        title: 'Booking requests are coming soon',
        message: 'You’ll pick dates and send a request to the owner here.',
      ),
    );
  }
}
