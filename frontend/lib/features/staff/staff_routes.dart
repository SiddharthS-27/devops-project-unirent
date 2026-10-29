import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'appeals/appeal_detail_screen.dart';
import 'appeals/appeals_queue_screen.dart';
import 'appeals/ruling_form_screen.dart';
import 'staff_section_screen.dart';
import 'staff_tab.dart';

/// The screen at the root of a staff tab.
Widget staffTabScreen(StaffTab tab) => switch (tab) {
  StaffTab.appeals => const AppealsQueueScreen(),
  _ => StaffSectionScreen(tab: tab),
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
          ],
        ),
      ],
      _ => const [],
    };
