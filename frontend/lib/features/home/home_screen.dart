import 'package:flutter/material.dart';

import '../../ui/ui.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: const EmptyState(
        icon: Icons.storefront_outlined,
        title: 'Nothing listed yet',
        message: 'Items from students on your campus will show up here.',
      ),
    );
  }
}
