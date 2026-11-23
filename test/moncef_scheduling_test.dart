import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_project/features/planning/planning_engine.dart';
import 'package:mobile_project/features/planning/planning_page.dart';
import 'package:mobile_project/features/planning/planning_store.dart';
import 'package:mobile_project/features/tasks/task_store.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'widget_test.dart' show MemoryPreferences;

class FailingPlanDisk extends MemoryPreferences {
  FailingPlanDisk(this.takeFailure);
  final bool Function() takeFailure;

  @override
  Future<void> setString(String key, String value) async {
    if (takeFailure()) {
      throw StateError('Device storage is temporarily unavailable.');
    }
    await super.setString(key, value);
  }
}

void main() {
  setUpAll(tz.initializeTimeZones);

  test(
    'task windows constrain real placement and defer blocked work',
    () async {
      final disk = MemoryPreferences();
      final tasks = TaskStore(disk);
      final plan = PlanningStore(
        disk,
        tasks,
        now: () => DateTime(2026, 6, 1, 8),
      );
      const date = '2026-06-02';
      await tasks.save(
        const Task(id: 'a', title: 'Prepare', due: date, minutes: 45),
      );
      await tasks.save(
        const Task(id: 'b', title: 'Review', requires: ['a'], minutes: 15),
      );
      const meeting = PlanBlock(
        'meeting',
        'Meeting',
        600,
        645,
        BlockKind.commitment,
      );
      final draft = plan.preview(
        date,
        constraint: meeting,
        windowsOverride: {'a': (start: 600, end: 720)},
      );
      expect(draft.result.blocks.single.interval, (start: 645, end: 690));
      final review = draft.result.changes.singleWhere(
        (change) => change.id == 'b',
      );
      expect(review.kind, ChangeKind.deferred);
      expect(review.reason, contains('Prepare'));
      expect(plan.unscheduled(date).map((task) => task.title), [
        'Prepare',
        'Review',
      ]);
      await plan.approve(draft);
      expect(plan.unscheduled(date).single.title, 'Review');

      final noFit = plan.preview(
        date,
        windowsOverride: {'a': (start: 620, end: 650)},
      );
      expect(noFit.result.blocks, isEmpty);
      expect(
        noFit.result.changes.firstWhere((change) => change.id == 'a').reason,
        contains('10:20–10:50'),
      );
      expect(plan.day(date).approved.single.start, 645);
    },
  );

  test(
    'accounts use civil dates and reject nonexistent and repeated times',
    () async {
      final tasks = TaskStore(MemoryPreferences());
      final plan = PlanningStore(
        MemoryPreferences(),
        tasks,
        now: () => DateTime.utc(2026, 3, 8, 4, 30),
        timezone: () => 'America/New_York',
      );
      final utc = PlanningStore(
        MemoryPreferences(),
        tasks,
        now: () => DateTime.utc(2026, 3, 8, 4, 30),
        timezone: () => 'UTC',
      );
      expect(utc.cutoffFor('2026-03-08'), 271);
      expect(() => utc.preview('2026-03-08'), returnsNormally);
      expect(
        () => plan.preview('2026-03-08', workday: (start: 150, end: 360)),
        throwsStateError,
      );
      expect(dayKey(plan.localNow), '2026-03-07');
      expect(plan.cutoffFor('2026-03-07'), 1411);
      expect(plan.cutoffFor('2026-03-08'), 0);
      expect(() => plan.preview('2026-02-30'), throwsStateError);
      expect(
        () => plan.validateInterval('2026-03-08', (start: 90, end: 150)),
        throwsStateError,
      );
      expect(
        () => plan.validateInterval('2026-11-01', (start: 60, end: 70)),
        throwsStateError,
      );
      expect(
        () => plan.validateInterval('2026-11-01', (start: 1380, end: 1440)),
        returnsNormally,
      );
      expect(
        () => plan.validateInterval('2026-11-01', (start: 1380, end: 60)),
        throwsStateError,
      );

      await tasks.save(
        const Task(id: 'a', title: 'Ninety minutes', minutes: 90),
      );
      final spring = plan.preview('2026-03-08', workday: (start: 60, end: 300));
      expect(spring.result.blocks.single.interval, (start: 180, end: 270));
      final fall = plan.preview('2026-11-01', workday: (start: 0, end: 240));
      expect(fall.result.blocks.single.interval, (start: 120, end: 210));
    },
  );

  test(
    'overlapping reservations fail and history restores through a new approval',
    () async {
      final disk = MemoryPreferences();
      final plan = PlanningStore(
        disk,
        TaskStore(disk),
        now: () => DateTime(2026, 6, 1, 8),
      );
      const date = '2026-06-02';
      expect(
        () => plan.preview(
          date,
          constraint: const PlanBlock(
            'conflict',
            'Conflict',
            740,
            800,
            BlockKind.commitment,
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Lunch'),
          ),
        ),
      );
      const meeting = PlanBlock(
        'meeting',
        'Meeting',
        780,
        840,
        BlockKind.commitment,
      );
      await plan.approve(plan.preview(date, constraint: meeting));
      await plan.approve(
        plan.preview(date, reservedOverride: [plan.day(date).reserved.first]),
      );
      final reopened = PlanningStore(
        disk,
        plan.tasks,
        now: () => DateTime(2026, 6, 1, 8),
      );
      await reopened.load();
      final old = reopened.day(date).history.first;
      final restore = reopened.restoreRevision(date, old);
      expect(restore.reserved.map((block) => block.id), ['lunch', 'meeting']);
      expect(reopened.day(date).reserved.single.id, 'lunch');
      await reopened.approve(restore);
      expect(reopened.day(date).history.length, 3);
      expect(reopened.day(date).reserved.last.id, 'meeting');
      await expectLater(reopened.approve(restore), throwsStateError);
    },
  );

  test('reloading an equal revision invalidates a draft and recalculation keeps remote additions', () async {
    final disk = MemoryPreferences();
    final store = PlanningStore(
      disk,
      TaskStore(disk),
      now: () => DateTime(2026, 6, 1, 8),
    );
    const date = '2026-06-02';
    final draft = store.preview(date, workday: (start: 480, end: 1080));
    await disk.setString(
      'planify.planning.v1',
      jsonEncode({
        date: const DayPlan(
          reserved: [
            PlanBlock('remote', 'Remote change', 600, 660, BlockKind.pause),
          ],
        ).toJson(),
      }),
    );
    await store.load();
    expect(store.day(date).version, draft.version);
    expect(store.isStale(draft), isTrue);
    final refreshed = store.recalculate(draft);
    expect(refreshed.workday.start, 480);
    await store.approve(refreshed);
    expect(store.day(date).reserved.single.id, 'remote');
  });

  test('past interruptions retain unaffected elapsed slices and replan remaining work', () async {
    var now = DateTime(2026, 6, 2, 8);
    final disk = MemoryPreferences();
    final tasks = TaskStore(disk);
    final plan = PlanningStore(disk, tasks, now: () => now);
    const date = '2026-06-02';
    await tasks.save(const Task(id: 'a', title: 'Prepare', minutes: 180));
    await plan.approve(plan.preview(date));
    now = DateTime(2026, 6, 2, 11);
    const event = (id: 'focus-42-1', start: 570, end: 600);
    final draft = plan.preview(date, interruption: event);
    expect(draft.result.blocks.map((block) => block.interval), [
      (start: 540, end: 570),
      (start: 600, end: 661),
      (start: 780, end: 869),
    ]);
    expect(plan.day(date).approved.single.end, 720);
    await plan.approve(draft);
    expect(() => plan.preview(date, interruption: event), throwsStateError);
  });

  testWidgets(
    'stale review blocks approval and a failed save leaves review open',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var fail = false;
      final disk = FailingPlanDisk(() {
        if (!fail) return false;
        fail = false;
        return true;
      });
      final tasks = TaskStore(disk);
      final plan = PlanningStore(
        disk,
        tasks,
        now: () => DateTime(2026, 6, 2, 8),
      );
      await tester.pumpWidget(MaterialApp(home: PlanningPage(store: plan)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.text('Generate schedule'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tasks.save(const Task(id: 'a', title: 'New task'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        find.textContaining('This preview is out of date'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Approve'))
            .onPressed,
        isNull,
      );
      await tester.tap(find.text('Recalculate'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      fail = true;
      await tester.tap(find.text('Approve'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(
        find.text('Device storage is temporarily unavailable.'),
        findsOneWidget,
      );
      expect(plan.day('2026-06-02').history, isEmpty);
      await tester.tap(find.text('Approve'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(plan.day('2026-06-02').history.length, 1);
      expect(plan.day('2026-06-02').approved.single.title, 'New task');
    },
  );
}
