import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/ui.dart';

class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Not found')),
      body: EmptyState(
        icon: Icons.link_off,
        title: 'Page not found',
        message: 'This link may be broken or no longer available.',
        // Redirects send each role to its own start page from '/'.
        action: AppButton(label: 'Go home', onPressed: () => context.go('/')),
      ),
    );
  }
}
