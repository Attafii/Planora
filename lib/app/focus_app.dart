import 'package:flutter/material.dart';

import '../features/focus/focus_store.dart';
import '../features/focus/pages.dart';
import '../features/home/home_page.dart';
import 'theme/app_colors.dart';

class MobileShell extends StatefulWidget {
  const MobileShell({
    super.key,
    required this.store,
    this.embedded = false,
    this.syncStatus,
  });
  final Widget? syncStatus;
  final FocusStore store;
  final bool embedded;
  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> {
  int index = 0;
  @override
  void initState() {
    super.initState();
    widget.store.notifications.onOpen = () {
      if (mounted) {
        setState(
          () => index =
              widget.store.notifications.openedReminder == '2000000001' ? 1 : 2,
        );
      }
    };
    if (widget.store.notifications.openedReminder != null) index = 2;
  }

  @override
  void dispose() {
    widget.store.notifications.onOpen = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final navigation = NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (v) => setState(() => index = v),
      backgroundColor: Theme.of(context).colorScheme.surface,
      indicatorColor: Theme.of(context).colorScheme.primaryContainer,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.wb_sunny_outlined),
          selectedIcon: Icon(Icons.wb_sunny_rounded),
          label: 'Today',
        ),
        NavigationDestination(
          icon: Icon(Icons.timelapse_outlined),
          selectedIcon: Icon(Icons.timelapse),
          label: 'Focus',
        ),
        NavigationDestination(
          icon: Icon(Icons.notifications_none_rounded),
          selectedIcon: Icon(Icons.notifications_rounded),
          label: 'Reminders',
        ),
        NavigationDestination(
          icon: Icon(Icons.bar_chart_rounded),
          label: 'Time log',
        ),
      ],
    );
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (widget.embedded) navigation,
            if (s.error != null)
              MaterialBanner(
                content: Text(s.error!),
                actions: [
                  TextButton(
                    onPressed: () {
                      s.error = null;
                      s.save();
                    },
                    child: const Text('Retry save'),
                  ),
                ],
              ),
            Expanded(
              child: IndexedStack(
                index: index,
                children: [
                  HomePage(
                    store: s,
                    onFocus: () =>
                        openFocus(context, s, syncStatus: widget.syncStatus),
                    onReminders: () => setState(() => index = 2),
                  ),
                  FocusLanding(store: s, syncStatus: widget.syncStatus),
                  RemindersPage(store: s),
                  HistoryPage(store: s, syncStatus: widget.syncStatus),
                ],
              ),
            ),
            if (s.active != null)
              Material(
                color: ink,
                child: InkWell(
                  onTap: () =>
                      openFocus(context, s, syncStatus: widget.syncStatus),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.graphic_eq_rounded, color: teal),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            s.active!.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        Text(
                          clock(s.active!.elapsed(s.now)),
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: widget.embedded ? null : navigation,
    );
  }
}
