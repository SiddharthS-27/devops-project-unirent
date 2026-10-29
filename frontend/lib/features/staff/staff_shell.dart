import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/session.dart';
import 'staff_tab.dart';

/// Staff console frame: a scrollable tab strip of the sections the current
/// role may see. Branch indexes follow [StaffTab.values].
class StaffShell extends ConsumerWidget {
  const StaffShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabs = StaffTab.visibleTo(ref.watch(sessionProvider).status);
    // Briefly empty while signing out, before the redirect lands.
    if (tabs.isEmpty) return const SizedBox.shrink();

    final current = StaffTab.values[navigationShell.currentIndex];
    return Scaffold(
      appBar: AppBar(
        title: Text(current.label),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: ref.read(sessionProvider.notifier).signOut,
          ),
        ],
        bottom: _StaffTabBar(
          tabs: tabs,
          current: current,
          onSelected: (tab) => navigationShell.goBranch(
            tab.index,
            initialLocation: tab == current,
          ),
        ),
      ),
      body: navigationShell,
    );
  }
}

class _StaffTabBar extends StatelessWidget implements PreferredSizeWidget {
  const _StaffTabBar({
    required this.tabs,
    required this.current,
    required this.onSelected,
  });

  final List<StaffTab> tabs;
  final StaffTab current;
  final ValueChanged<StaffTab> onSelected;

  @override
  Size get preferredSize => const Size.fromHeight(kTextTabBarHeight);

  @override
  Widget build(BuildContext context) {
    final index = tabs.indexOf(current).clamp(0, tabs.length - 1);
    // The router owns the selected tab, so the controller is recreated
    // whenever the selection or the tab list changes.
    return DefaultTabController(
      key: ValueKey('${tabs.length}:$index'),
      length: tabs.length,
      initialIndex: index,
      child: TabBar(
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        onTap: (i) => onSelected(tabs[i]),
        tabs: [for (final tab in tabs) Tab(text: tab.label)],
      ),
    );
  }
}
