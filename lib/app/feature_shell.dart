import 'package:flutter/material.dart';

import 'app_services.dart';
import 'theme/app_colors.dart';
import '../core/widgets/product_widgets.dart';
import '../features/goals/presentation/goals_page.dart';
import '../features/collaboration/presentation/projects_page.dart';
import '../features/assistant/presentation/conversations_page.dart';
import '../features/gamification/presentation/achievements_page.dart';

class FeatureShell extends StatefulWidget {
  const FeatureShell({super.key});
  @override
  State<FeatureShell> createState() => _FeatureShellState();
}

class _FeatureShellState extends State<FeatureShell> {
  int _selected = 0;
  static const _labels = ['Goals', 'Projects', 'Assistant', 'Achievements'];
  static const _icons = [
    Icons.flag_outlined,
    Icons.people_outline,
    Icons.auto_awesome_outlined,
    Icons.workspace_premium_outlined,
  ];
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 850,
        user = AppScope.of(context).session.user!;
    final pages = [
      const GoalsPage(embedded: true),
      const ProjectsPage(embedded: true),
      const ConversationsPage(embedded: true),
      const AchievementsPage(embedded: true),
    ];
    return Scaffold(
      appBar: wide
          ? null
          : AppBar(
              title: Image.asset(
                'assets/branding/identity-source/approved-logo.png',
                width: 140,
                height: 60,
              ),
              actions: [
                IconButton(
                  tooltip: 'Account: ${user.name}',
                  onPressed: () => _account(context),
                  icon: const Icon(Icons.account_circle_outlined),
                ),
              ],
            ),
      body: SafeArea(
        child: Row(
          children: [
            if (wide) ...[
              SizedBox(
                width: 230,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
                      child: Image.asset(
                        'assets/branding/identity-source/approved-logo.png',
                        height: 90,
                        width: 200,
                      ),
                    ),
                    Expanded(
                      child: NavigationRail(
                        extended: true,
                        minExtendedWidth: 220,
                        backgroundColor: AppColors.paper,
                        selectedIndex: _selected,
                        onDestinationSelected: (i) =>
                            setState(() => _selected = i),
                        destinations: [
                          for (int i = 0; i < _labels.length; i++)
                            NavigationRailDestination(
                              icon: Icon(_icons[i]),
                              label: Text(_labels[i]),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextButton.icon(
                        onPressed: () => _account(context),
                        icon: const Icon(Icons.account_circle_outlined),
                        label: Text(user.name, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1),
            ],
            Expanded(
              child: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                child: KeyedSubtree(
                  key: ValueKey(_selected),
                  child: pages[_selected],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _selected,
              onDestinationSelected: (i) => setState(() => _selected = i),
              destinations: [
                for (int i = 0; i < _labels.length; i++)
                  NavigationDestination(
                    icon: Icon(_icons[i]),
                    label: _labels[i],
                  ),
              ],
            ),
    );
  }

  Future<void> _account(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (ctx) {
      final user = AppScope.of(context).session.user!;
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(user.email),
            Text('Timezone: ${user.timezone}'),
            const SizedBox(height: 24),
            BusyButton(
              label: 'Sign out',
              outlined: true,
              onPressed: () async {
                await AppScope.of(context).session.signOut();
              },
            ),
          ],
        ),
      );
    },
  );
}
