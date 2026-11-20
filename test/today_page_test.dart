import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_project/app/today_page.dart';
import 'package:mobile_project/features/planning/planning_store.dart';
import 'package:mobile_project/features/tasks/task_store.dart';

import 'widget_test.dart' show MemoryPreferences;

void main() {
  testWidgets('Today opens the task list and saves a daily check-in', (
    tester,
  ) async {
    final prefs = MemoryPreferences();
    final tasks = TaskStore(prefs);
    await tasks.save(
      const Task(id: 'one', title: 'Call Sam', activity: ActivityType.personal),
    );
    final planning = PlanningStore(prefs, tasks);
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TodayPage(
            tasks: tasks,
            planning: planning,
            accountId: 'local',
            storage: prefs,
            onCalendar: () {},
            onTasks: () => opened = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 ready to start'), findsOneWidget);
    await tester.tap(find.text('My tasks'));
    expect(opened, isTrue);
    await tester.ensureVisible(find.text('Daily check-in'));
    await tester.tap(find.text('Daily check-in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Good'));
    await tester.pumpAndSettle();
    expect(
      prefs.values['planify.mood.local.${dayKey(DateTime.now())}'],
      'Good',
    );
    final restored = TaskStore(prefs);
    await restored.load();
    expect(restored.get('one')!.activity, ActivityType.personal);
    await tester.pumpWidget(const SizedBox());
    restored.dispose();
    planning.dispose();
    tasks.dispose();
  });
}
