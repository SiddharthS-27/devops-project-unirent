import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// Placeholder; the full detail screen comes with the listing-detail step.
class ListingDetailScreen extends StatelessWidget {
  const ListingDetailScreen({super.key, required this.listingId});

  final String listingId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Listing')),
      body: EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Listing details',
        message: listingId,
      ),
    );
  }
}
