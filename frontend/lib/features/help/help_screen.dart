import 'package:flutter/material.dart';

import '../../ui/ui.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & support')),
      body: const EmptyState(
        icon: Icons.help_outline,
        title: 'How can we help?',
        message: 'FAQs and support tickets will appear here.',
      ),
    );
  }
}
