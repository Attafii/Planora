import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:mobile_project/features/planning/google_plan_sync.dart';
import 'package:mobile_project/features/planning/planning_store.dart';
import 'package:mobile_project/features/tasks/task_store.dart';

import 'widget_test.dart' show MemoryPreferences;

void main() {
  setUpAll(tz.initializeTimeZones);
  test('busy imports honor all-day exclusive end, transparency and existing breaks; approval remains required', () async {
    final disk = MemoryPreferences(), tasks = TaskStore(MemoryPreferences());
    final plan = PlanningStore(
      disk,
      tasks,
      timezone: () => 'Africa/Tunis',
      now: () => DateTime.utc(2026, 11, 23, 7),
    );
    const date = '2026-11-24';
    final events = [
      {
        'start': {'dateTime': '2026-11-24T09:00:00+01:00'},
        'end': {'dateTime': '2026-11-24T10:00:00+01:00'},
      },
      {
        'transparency': 'transparent',
        'start': {'date': date},
        'end': {'date': '2026-11-25'},
      },
    ];
    final blocks = googleBusyBlocks(plan, date, events);
    expect(blocks.where((b) => b.id.startsWith('google:')).single.start, 540);
    expect(plan.day(date).reserved.length, 1);
    final draft = plan.preview(date, reservedOverride: blocks);
    await plan.approve(draft);
    expect(googleBusyBlocks(plan, date, events).length, blocks.length);
    expect(plan.isStale(draft), true);
    final allDay = googleBusyBlocks(plan, date, [
      {
        'start': {'date': date},
        'end': {'date': '2026-11-25'},
      },
    ]);
    expect(allDay.fold<int>(0, (n, b) => n + b.end - b.start), 1440);
    expect(
      googleBusyBlocks(plan, '2026-11-25', [
        {
          'start': {'date': date},
          'end': {'date': '2026-11-25'},
        },
      ]).length,
      1,
    );
  });
  test(
    'approved exports are stable across retries and use account timezone',
    () async {
      final disk = MemoryPreferences(), tasks = TaskStore(MemoryPreferences());
      await tasks.save(const Task(id: 'work', title: 'Work', minutes: 30));
      final plan = PlanningStore(
        disk,
        tasks,
        timezone: () => 'Africa/Tunis',
        now: () => DateTime.utc(2026, 11, 23, 7),
      );
      await plan.approve(plan.preview('2026-11-24'));
      final first = approvedGoogleExports(plan, '2026-11-24', 'account-a');
      expect(first, isNotEmpty);
      expect(first, approvedGoogleExports(plan, '2026-11-24', 'account-a'));
      expect(
        first.first['request_id'],
        isNot(
          approvedGoogleExports(
            plan,
            '2026-11-24',
            'account-b',
          ).first['request_id'],
        ),
      );
      expect(first.first['start'], '2026-11-24T08:00:00.000Z');
    },
  );
}
