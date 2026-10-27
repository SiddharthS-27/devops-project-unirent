import 'package:flutter/material.dart';

import '../../ui/ui.dart';

/// Placeholder; the edit form comes with the add/edit-listing step.
class EditListingScreen extends StatelessWidget {
  const EditListingScreen({super.key, required this.listingId});

  final String listingId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit listing')),
      body: const EmptyState(
        icon: Icons.edit_outlined,
        title: 'Editing is coming soon',
      ),
    );
  }
}
