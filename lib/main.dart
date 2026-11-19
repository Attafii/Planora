import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/tasks/task_store.dart';
import 'features/planning/planning_page.dart';
import 'features/planning/planning_store.dart';
import 'features/tasks/tasks_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(Planify(store: TaskStore(SharedPreferencesAsync())));
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
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF3B82F6),
        primary: const Color(0xFF051B47),
        surface: const Color(0xFFFAF9F6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    darkTheme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF3B82F6),
        brightness: Brightness.dark,
      ),
    ),
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
