import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_project/features/planning/calendar_panel.dart';
import 'package:mobile_project/features/planning/planning_engine.dart';
import 'package:mobile_project/features/planning/planning_store.dart';
import 'package:mobile_project/features/tasks/task_store.dart';
import 'package:mobile_project/main.dart';

import 'widget_test.dart' show MemoryPreferences;

void main() {
  test('civil date navigation handles leap days and year boundaries', () {
    expect(
      shiftCalendarDate(DateTime(2028, 1, 31), CalendarView.month, 1),
      DateTime(2028, 2, 29),
    );
    expect(
      shiftCalendarDate(DateTime(2026, 12, 31), CalendarView.day, 1),
      DateTime(2027, 1, 1),
    );
    expect(
      shiftCalendarDate(DateTime(2026, 12, 30), CalendarView.week, 1),
      DateTime(2027, 1, 6),
    );
  });

  test(
    'future calendar days beyond the inbox horizon include recurring work',
    () async {
      final storage = MemoryPreferences();
      final tasks = TaskStore(storage);
      final now = DateTime.now();
      final anchor = dayKey(now);
      final future = dayKey(addCalendarDays(now, 84));
      final plan = PlanningStore(storage, tasks);
      await tasks.save(
        Task(
          id: 'weekly',
          title: 'Review notes',
          due: anchor,
          repeat: Repeat.weekly,
        ),
      );
      final draft = plan.preview(future);
      expect(draft.result.blocks.single.id, 'weekly@$future');
    },
  );

  testWidgets('month and week cells open the agenda for the selected date', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final storage = MemoryPreferences();
    final tasks = TaskStore(storage);
    final plans = PlanningStore(storage, tasks);
    final now = DateTime.now();
    final tomorrow = dayKey(addCalendarDays(now, 1));
    await plans.approve(
      plans.preview(
        tomorrow,
        constraint: const PlanBlock(
          'meeting',
          'Team meeting',
          600,
          660,
          BlockKind.commitment,
        ),
      ),
    );
    await tester.pumpWidget(Planify(store: tasks, planningStorage: storage));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    final tomorrowCell = find.byKey(ValueKey('calendar-$tomorrow'));
    if (tomorrowCell.evaluate().isEmpty) {
      await tester.tap(find.byTooltip('Next month'));
      await tester.pumpAndSettle();
    }
    await tester.tap(tomorrowCell);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Team meeting'), findsOneWidget);
    await tester.tap(find.text('Week'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Next week'), findsOneWidget);
    await tester.tap(find.text('Day'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Next day'), findsOneWidget);
  });
}
