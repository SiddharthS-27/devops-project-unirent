import 'package:flutter/material.dart';

import '../../ui/ui.dart';
import 'staff_tab.dart';

/// Placeholder for a staff console section. The title is shown by the
/// enclosing [StaffShell] app bar.
class StaffSectionScreen extends StatelessWidget {
  const StaffSectionScreen({super.key, required this.tab});

  final StaffTab tab;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: EmptyState(
        icon: tab.icon,
        title: tab.label,
        message: 'Nothing here yet.',
      ),
    );
  }
}
