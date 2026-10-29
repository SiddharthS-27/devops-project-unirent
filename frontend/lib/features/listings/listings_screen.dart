import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../ui/ui.dart';

/// The student's own listings and the bookings made against them.
class ListingsScreen extends StatelessWidget {
  const ListingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Listings')),
      body: EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No listings yet',
        message: 'List something to rent out or sell.',
        action: AppButton.secondary(
          label: 'Open sample booking',
          onPressed: () => context.push(Routes.booking('sample')),
        ),
      ),
    );
  }
}
