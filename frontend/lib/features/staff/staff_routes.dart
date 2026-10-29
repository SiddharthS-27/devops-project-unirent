import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'admin/late_fee_rule_screen.dart';
import 'admin/moderators_screen.dart';
import 'appeals/appeal_detail_screen.dart';
import 'appeals/appeals_queue_screen.dart';
import 'appeals/ruling_form_screen.dart';
import 'escalations/escalations_screen.dart';
import 'listings/staff_listings_screen.dart';
import 'reports/reconciliation_report_screen.dart';
import 'reports/reports_screen.dart';
import 'staff_tab.dart';
import 'support/staff_thread_screen.dart';
import 'support/support_inbox_screen.dart';
import 'users/user_detail_screen.dart';
import 'users/users_screen.dart';

/// The screen at the root of a staff tab.
Widget staffTabScreen(StaffTab tab) => switch (tab) {
  StaffTab.appeals => const AppealsQueueScreen(),
  StaffTab.support => const SupportInboxScreen(),
  StaffTab.escalations => const EscalationsScreen(),
  StaffTab.users => const UsersScreen(),
  StaffTab.listings => const StaffListingsScreen(),
  StaffTab.reports => const ReportsScreen(),
  StaffTab.lateFeeRule => const LateFeeRuleScreen(),
  StaffTab.moderators => const ModeratorsScreen(),
};

/// Detail pages under a staff tab; they open over the shell (on [root]).
List<RouteBase> staffTabRoutes(StaffTab tab, GlobalKey<NavigatorState> root) =>
    switch (tab) {
      StaffTab.appeals => [
        GoRoute(
          path: ':id',
          parentNavigatorKey: root,
          builder: (context, state) =>
              AppealDetailScreen(appealId: state.pathParameters['id']!),
          routes: [
            GoRoute(
              path: 'rule',
              parentNavigatorKey: root,
              builder: (context, state) =>
                  RulingFormScreen(appealId: state.pathParameters['id']!),
            ),
            GoRoute(
              path: 'overrule',
              parentNavigatorKey: root,
              builder: (context, state) => RulingFormScreen(
                appealId: state.pathParameters['id']!,
                overrule: true,
              ),
            ),
          ],
        ),
      ],
      StaffTab.support => [
        GoRoute(
          path: ':id',
          parentNavigatorKey: root,
          builder: (context, state) =>
              StaffThreadScreen(threadId: state.pathParameters['id']!),
        ),
      ],
      // Flagged students open from Escalations too, under this path.
      StaffTab.users => [
        GoRoute(
          path: ':id',
          parentNavigatorKey: root,
          builder: (context, state) =>
              UserDetailScreen(accountId: state.pathParameters['id']!),
        ),
      ],
      StaffTab.reports => [
        GoRoute(
          path: 'runs/:id',
          parentNavigatorKey: root,
          builder: (context, state) =>
              ReconciliationReportScreen(runId: state.pathParameters['id']!),
        ),
      ],
      _ => const [],
    };
