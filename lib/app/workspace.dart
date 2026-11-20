import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/account/account_screens.dart';
import '../features/tasks/task_agent.dart';
import '../features/planning/planning_agent.dart';
import '../core/services/app_session.dart';
import '../features/assistant/presentation/conversations_page.dart';
import '../features/focus/focus_store.dart';
import 'focus_app.dart' show MobileShell;
import '../features/planning/planning_page.dart';
import '../features/planning/planning_store.dart';
import '../features/tasks/task_store.dart';
import '../features/tasks/tasks_page.dart';

class Workspace extends StatefulWidget {
  const Workspace({super.key, required this.session});

  final AppSession session;

  @override
  State<Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<Workspace> {
  final storage = SharedPreferencesAsync();
  late final tasks = TaskStore(storage, accountId: widget.session.account!.id);
  late final planning = PlanningStore(
    storage,
    tasks,
    accountId: widget.session.account!.id,
  );
  late final focus = FocusStore(
    accountId: widget.session.account!.id,
    proposeAgent: (body) =>
        widget.session.request('POST', '/agents/focus', body),
  );
  late Future<void> ready = load();
  int selected = 0;

  static const destinations = [
    (Icons.checklist_rounded, 'Tasks'),
    (Icons.calendar_month_outlined, 'Calendar'),
    (Icons.timer_outlined, 'Focus'),
    (Icons.auto_awesome_outlined, 'Assistant'),
    (Icons.more_horiz, 'More'),
  ];

  Future<void> load() async {
    await tasks.load();
    await Future.wait([planning.load(), focus.load()]);
  }

  @override
  void dispose() {
    planning.dispose();
    focus.dispose();
    tasks.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      appBar: AppBar(
        title: const Brand(),
        actions: [
          IconButton(
            tooltip: 'Account and preferences',
            onPressed: () => Navigator.pushNamed(context, '/account'),
            icon: const Icon(Icons.account_circle_outlined),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: FutureBuilder<void>(
          future: ready,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: FilledButton(
                  onPressed: () => setState(() => ready = load()),
                  child: const Text('Could not load your workspace. Retry'),
                ),
              );
            }
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            return Row(
              children: [
                if (wide)
                  NavigationRail(
                    selectedIndex: selected,
                    onDestinationSelected: select,
                    extended: true,
                    destinations: [
                      for (final (icon, label) in destinations)
                        NavigationRailDestination(
                          icon: Icon(icon),
                          label: Text(label),
                        ),
                    ],
                  ),
                Expanded(
                  child: IndexedStack(
                    index: selected,
                    children: [
                      TasksPage(
                        store: tasks,
                        agent: TaskAgent(session: widget.session),
                      ),
                      PlanningPage(
                        store: planning,
                        agent: PlanningAgent(session: widget.session),
                      ),
                      ListenableBuilder(
                        listenable: focus,
                        builder: (_, _) =>
                            MobileShell(store: focus, embedded: true),
                      ),
                      const ConversationsPage(embedded: true),
                      const _MorePage(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: selected,
              onDestinationSelected: select,
              destinations: [
                for (final (icon, label) in destinations)
                  NavigationDestination(icon: Icon(icon), label: label),
              ],
            ),
    );
  }

  void select(int index) => setState(() => selected = index);
}

class _MorePage extends StatelessWidget {
  const _MorePage();

  static const links = [
    (
      Icons.flag_outlined,
      'Goals',
      'Set milestones and track long-term progress',
      '/goals',
    ),
    (
      Icons.people_outline,
      'Projects',
      'Plan work together and manage invitations',
      '/projects',
    ),
    (
      Icons.workspace_premium_outlined,
      'Achievements',
      'See your progress, streaks and rewards',
      '/achievements',
    ),
    (
      Icons.emoji_events_outlined,
      'Challenges',
      'Find and join a productivity challenge',
      '/challenges',
    ),
    (
      Icons.settings_outlined,
      'Preferences',
      'Change appearance, language and timezone',
      '/preferences',
    ),
  ];

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Your workspace',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 20),
          for (final (icon, title, description, route) in links)
            Card(
              child: ListTile(
                leading: Icon(icon),
                title: Text(title),
                subtitle: Text(description),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.pushNamed(context, route),
              ),
            ),
        ],
      ),
    ),
  );
}
