import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/tasks/task_store.dart';
import 'features/tasks/tasks_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(Planify(store: TaskStore(SharedPreferencesAsync())));
}

class Planify extends StatefulWidget {
  const Planify({super.key, required this.store});
  final TaskStore store;

  @override
  State<Planify> createState() => _PlanifyState();
}

class _PlanifyState extends State<Planify> {
  late Future<void> ready = widget.store.load();

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
                onPressed: () => setState(() => ready = widget.store.load()),
                child: const Text('Could not load tasks. Retry'),
              ),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return TasksPage(store: widget.store);
      },
    ),
  );
}
