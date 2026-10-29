import 'package:flutter/material.dart';

import '../../app/session.dart';

/// Sections of the staff console. Order defines tab order.
enum StaffTab {
  appeals('appeals', 'Appeals', Icons.gavel_outlined),
  support('support', 'Support', Icons.support_agent_outlined),
  escalations('escalations', 'Escalations', Icons.report_problem_outlined),
  users('users', 'Users', Icons.people_outline),
  listings('listings', 'Listings', Icons.inventory_2_outlined),
  reports('reports', 'Reports', Icons.bar_chart_outlined, adminOnly: true),
  lateFeeRule(
    'late-fee',
    'Late-fee rule',
    Icons.schedule_outlined,
    adminOnly: true,
  ),
  moderators(
    'moderators',
    'Moderators',
    Icons.admin_panel_settings_outlined,
    adminOnly: true,
  );

  const StaffTab(this.segment, this.label, this.icon, {this.adminOnly = false});

  final String segment;
  final String label;
  final IconData icon;
  final bool adminOnly;

  String get path => '/staff/$segment';

  bool isVisibleTo(SessionStatus session) =>
      session == SessionStatus.admin ||
      (session == SessionStatus.moderator && !adminOnly);

  /// Tabs shown to [session], in display order.
  static List<StaffTab> visibleTo(SessionStatus session) =>
      values.where((tab) => tab.isVisibleTo(session)).toList();

  /// The tab whose section contains [path], if any.
  static StaffTab? forPath(String path) {
    for (final tab in values) {
      if (path == tab.path || path.startsWith('${tab.path}/')) return tab;
    }
    return null;
  }
}
