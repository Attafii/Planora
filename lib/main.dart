import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'app/account_app.dart';
import 'app/app_services.dart';
import 'app/workspace.dart';
import 'core/network/api_client.dart';
import 'core/services/app_session.dart' as account;

import 'app/theme/app_theme.dart';
import 'features/tasks/task_store.dart';
import 'features/planning/planning_page.dart';
import 'features/planning/planning_store.dart';
import 'features/tasks/tasks_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  runApp(const PlanifyRoot());
}

class PlanifyRoot extends StatefulWidget {
  const PlanifyRoot({super.key});

  @override
  State<PlanifyRoot> createState() => _PlanifyRootState();
}

class _PlanifyRootState extends State<PlanifyRoot> {
  final accountSession = account.AppSession(baseUrl: ApiClient().baseUrl);
  late AppServices services = newServices();

  AppServices newServices() =>
      AppServices(client: ApiClient(baseUrl: accountSession.baseUrl));

  @override
  void initState() {
    super.initState();
    accountSession.addListener(syncAccount);
    accountSession.restore();
  }

  void syncAccount() {
    final user = accountSession.account;
    final token = user == null ? null : accountSession.accessToken;
    if (services.api.token != token) {
      services.api.token = null;
      services.api.onUnauthorized = null;
      services.api.close();
      services.session.dispose();
      setState(() => services = newServices());
    }
    services.api.token = token;
    services.api.onUnauthorized = accountSession.invalidateSession;
    services.session.user = user == null
        ? null
        : AuthUser.fromJson({
            'id': user.id,
            'name': user.name,
            'email': user.email,
            'timezone': user.timezone,
          });
  }

  @override
  void dispose() {
    accountSession.removeListener(syncAccount);
    accountSession.dispose();
    services.session.dispose();
    services.api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppScope(
    services: services,
    child: PlanifyApp(
      session: accountSession,
      services: services,
      workspace: (_) => Workspace(
        key: ValueKey(accountSession.account!.id),
        session: accountSession,
      ),
    ),
  );
}

class Planify extends StatefulWidget {
  const Planify({super.key, required this.store, this.planningStorage});
  final TaskStore store;
  final SharedPreferencesAsync? planningStorage;

  @override
  State<Planify> createState() => _PlanifyState();
}

class _PlanifyState extends State<Planify> {
  late final planning = PlanningStore(
    widget.planningStorage ?? SharedPreferencesAsync(),
    widget.store,
  );
  late Future<void> ready = load();
  int selected = 0;

  Future<void> load() async {
    await widget.store.load();
    await planning.load();
  }

  @override
  void dispose() {
    planning.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Planify',
    theme: AppTheme.light,
    darkTheme: PlanifyTheme.build(Brightness.dark),
    home: FutureBuilder<void>(
      future: ready,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => setState(() => ready = load()),
                child: const Text('Could not load Planify. Retry'),
              ),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return Scaffold(
          body: IndexedStack(
            index: selected,
            children: [
              TasksPage(store: widget.store),
              PlanningPage(store: planning),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: selected,
            onDestinationSelected: (index) => setState(() => selected = index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.checklist),
                label: 'Tasks',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_month_outlined),
                label: 'Calendar',
              ),
            ],
          ),
        );
      },
    ),
  );
}
