import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_project/app/today_page.dart';
import 'package:mobile_project/app/daily_dock.dart';
import 'package:mobile_project/features/planning/planning_store.dart';
import 'package:mobile_project/features/tasks/task_store.dart';

import 'widget_test.dart' show MemoryPreferences;

void main() {
  testWidgets(
    'completed scheduled work stays in the timeline without a focus action',
    (tester) async {
      final prefs = MemoryPreferences();
      final tasks = TaskStore(prefs);
      final planning = PlanningStore(
        prefs,
        tasks,
        now: () => DateTime(2026, 6, 2, 8),
      );
      addTearDown(tasks.dispose);
      addTearDown(planning.dispose);
      const task = Task(id: 'review', title: 'Review draft');
      await tasks.save(task);
      await planning.approve(planning.preview('2026-06-02'));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TodayPage(
              tasks: tasks,
              planning: planning,
              accountId: 'local',
              storage: prefs,
              onCalendar: () {},
              onTasks: () {},
              onStartFocus: (_, _) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Start focus'), findsOneWidget);
      await tasks.markDone(task.id);
      await tester.pumpAndSettle();
      expect(find.text('Start focus'), findsNothing);
      final timeline = find.widgetWithText(ListTile, 'Review draft');
      await tester.ensureVisible(timeline);
      expect(tester.widget<ListTile>(timeline).onTap, isNull);
      expect(find.textContaining('This task is already done.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('the dock keeps five named destinations at large text sizes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    int? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 700),
            textScaler: TextScaler.linear(2),
            disableAnimations: true,
          ),
          child: Scaffold(
            bottomNavigationBar: DailyDock(
              destinations: const [
                (Icons.wb_sunny, 'Today'),
                (Icons.calendar_month, 'Calendar'),
                (Icons.timer, 'Focus'),
                (Icons.auto_awesome, 'Assistant'),
                (Icons.more_horiz, 'More'),
              ],
              selected: 3,
              onSelect: (index) => selected = index,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final nav = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(nav.animationDuration, Duration.zero);
    expect(nav.labelBehavior, NavigationDestinationLabelBehavior.alwaysHide);
    for (final label in ['Today', 'Calendar', 'Focus', 'Assistant', 'More']) {
      expect(find.bySemanticsLabel(RegExp('^$label')), findsWidgets);
    }
    await tester.tap(find.byIcon(Icons.calendar_month));
    expect(selected, 1);
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

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
